import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_models.dart';

final _rng = Random();
int roll1d6() => _rng.nextInt(6) + 1;
int roll2d6() => roll1d6() + roll1d6();

// ── Chargement du livre ───────────────────────────────────

final gameBookProvider = FutureProvider<GameBook>((ref) async {
  final raw = await rootBundle.loadString('assets/data/game_structure.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return GameBook.fromJson(json);
});

// ── Chapitre courant ──────────────────────────────────────

final currentChapterProvider = Provider<GameChapter?>((ref) {
  final bookAsync = ref.watch(gameBookProvider);
  final state = ref.watch(playerStateProvider);
  return bookAsync.whenOrNull(
    data: (book) => book.chapterById(state.currentChapterId),
  );
});

// ── Paragraphe courant (si chapitre de jeu) ───────────────

final currentParagraphProvider = Provider<GameParagraph?>((ref) {
  final chapter = ref.watch(currentChapterProvider);
  final state = ref.watch(playerStateProvider);
  if (chapter == null || chapter.type != ChapterType.jeu) return null;
  final pid = state.currentParagraphId ?? chapter.paragrapheDepart;
  if (pid == null) return null;
  try {
    return chapter.paragraphes.firstWhere((p) => p.id == pid);
  } catch (_) {
    return null;
  }
});

// ── État du joueur ────────────────────────────────────────

class PlayerStateNotifier extends StateNotifier<PlayerState> {
  PlayerStateNotifier(super.initial);

  // Navigation
  void goToChapter(String chapterId, {String? paragraphId}) {
    state = state.copyWith(
      currentChapterId: chapterId,
      currentParagraphId: paragraphId,
    );
  }

  void goToParagraph(String paragraphId) {
    state = state.copyWith(currentParagraphId: paragraphId);
  }

  void goToNextChapter(GameBook book) {
    final current = book.chapterById(state.currentChapterId);
    if (current?.suivant != null) {
      final next = book.chapterById(current!.suivant!);
      if (next != null) {
        state = state.copyWith(
          currentChapterId: next.id,
          currentParagraphId: next.paragrapheDepart,
          clearParagraph: next.type == ChapterType.narration,
        );
      }
    }
  }

  // PV
  void takeDamage(int raw, {bool bypassArmor = false}) {
    final dmg = bypassArmor ? raw : (raw - state.armorReduction).clamp(0, 999);
    state = state.copyWith(currentHp: state.currentHp - dmg);
  }

  void heal(int amount) {
    final cap = state.maxHp + state.permanentHp;
    state = state.copyWith(currentHp: (state.currentHp + amount).clamp(0, cap));
  }

  void setStartingHp(int hp) {
    state = state.copyWith(maxHp: hp, currentHp: hp);
  }

  // XP
  void gainXp(int amount) {
    final newXp = state.experiencePoints + amount;
    final newPerm = newXp ~/ 20;
    if (newPerm > state.permanentHp) {
      state = state.copyWith(
        experiencePoints: newXp,
        permanentHp: newPerm,
        currentHp: state.currentHp + (newPerm - state.permanentHp),
      );
    } else {
      state = state.copyWith(experiencePoints: newXp);
    }
  }

  // Inventaire
  void addItem(InventoryItem item) {
    if (state.hasItem(item.id)) return;
    state = state.copyWith(inventory: [...state.inventory, item]);
  }

  void useConsumable(String itemId) {
    final idx = state.inventory.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final item = state.inventory[idx];
    if (item.usesRemaining <= 0) return;
    final updated = List<InventoryItem>.from(state.inventory);
    updated[idx] = item.copyWith(usesRemaining: item.usesRemaining - 1);
    if (item.effect == 'heal_2d6') heal(roll2d6());
    state = state.copyWith(inventory: updated);
  }

  // Bourse
  void addGold(int amount) {
    state = state.copyWith(purse: state.purse.copyWith(
      goldPieces: state.purse.goldPieces + amount));
  }

  void spendGold(int amount) {
    state = state.copyWith(purse: state.purse.copyWith(
      goldPieces: (state.purse.goldPieces - amount).clamp(0, 999999)));
  }

  // Loot / ennemis
  void markLootCollected(String id) {
    state = state.copyWith(collectedLoot: {...state.collectedLoot, id});
  }

  bool isLootCollected(String id) => state.collectedLoot.contains(id);

  void markEnemyDefeated(String id) {
    state = state.copyWith(defeatedEnemies: {...state.defeatedEnemies, id});
  }

  // Mort / reset
  void resetForNewRun(List<InventoryItem> startingInventory) {
    state = PlayerState(
      maxHp: state.maxHp,
      currentHp: state.maxHp,
      defeatedEnemies: state.defeatedEnemies,
      inventory: startingInventory,
      currentChapterId: 'ch_merlin',
    );
  }

  void restoreFrom(PlayerState saved) {
    state = saved;
  }
}

final playerStateProvider =
    StateNotifierProvider<PlayerStateNotifier, PlayerState>((ref) {
  return PlayerStateNotifier(const PlayerState(
    maxHp: 0, currentHp: 0, currentChapterId: 'ch_merlin',
  ));
});

// ── Moteur de combat ──────────────────────────────────────

enum CombatPhase { idle, playerTurn, enemyTurn, playerWon, playerDied }

class CombatState {
  final CombatPhase phase;
  final EnemyData? enemy;
  final List<String> log;
  final String? winParagraphId;
  final String? deathParagraphId;

  const CombatState({
    this.phase = CombatPhase.idle,
    this.enemy,
    this.log = const [],
    this.winParagraphId,
    this.deathParagraphId,
  });

  CombatState copyWith({
    CombatPhase? phase, EnemyData? enemy,
    List<String>? log, String? winParagraphId, String? deathParagraphId,
  }) => CombatState(
    phase: phase ?? this.phase,
    enemy: enemy ?? this.enemy,
    log: log ?? this.log,
    winParagraphId: winParagraphId ?? this.winParagraphId,
    deathParagraphId: deathParagraphId ?? this.deathParagraphId,
  );
}

class CombatNotifier extends StateNotifier<CombatState> {
  final Ref _ref;
  CombatNotifier(this._ref) : super(const CombatState());

  void startCombat(EnemyData enemyData, {
    required bool playerFirst,
    required String onWin,
    required String onDeath,
  }) {
    final enemy = enemyData.clone();
    state = CombatState(
      phase: playerFirst ? CombatPhase.playerTurn : CombatPhase.enemyTurn,
      enemy: enemy,
      log: ['⚔️ Combat contre ${enemy.name} (${enemy.currentHp} PV)'],
      winParagraphId: onWin,
      deathParagraphId: onDeath,
    );
    if (!playerFirst) _enemyAttacks();
  }

  String playerAttacks() {
    if (state.phase != CombatPhase.playerTurn) return '';
    final player = _ref.read(playerStateProvider);
    final enemy = state.enemy!.clone();
    final log = List<String>.from(state.log);
    final roll = roll2d6();
    final threshold = player.attackThreshold;

    if (roll > threshold) {
      final dmg = (roll - threshold) + player.weaponBonusDamage;
      enemy.currentHp -= dmg;
      log.add('🎲 $roll > $threshold → TOUCHÉ ! $dmg dégâts. ${enemy.name} : ${enemy.currentHp} PV');
      if (enemy.isDead || enemy.isKnockedOut) {
        log.add('✅ ${enemy.name} est vaincu !');
        _ref.read(playerStateProvider.notifier).gainXp(1);
        state = state.copyWith(phase: CombatPhase.playerWon, enemy: enemy, log: log);
      } else {
        state = state.copyWith(phase: CombatPhase.enemyTurn, enemy: enemy, log: log);
        _enemyAttacks();
      }
    } else {
      log.add('🎲 $roll ≤ $threshold → Manqué.');
      state = state.copyWith(phase: CombatPhase.enemyTurn, log: log);
      _enemyAttacks();
    }
    return log.last;
  }

  void useMagicFinger(String itemId) {
    if (state.phase != CombatPhase.playerTurn) return;
    _ref.read(playerStateProvider.notifier).useConsumable(itemId);
    final enemy = state.enemy!.clone();
    final log = List<String>.from(state.log);
    enemy.currentHp -= 10;
    log.add('✨ Doigt de Feu → 10 dégâts ! ${enemy.name} : ${enemy.currentHp} PV');
    if (enemy.isDead || enemy.isKnockedOut) {
      log.add('✅ ${enemy.name} est vaincu !');
      _ref.read(playerStateProvider.notifier).gainXp(1);
      state = state.copyWith(phase: CombatPhase.playerWon, enemy: enemy, log: log);
    } else {
      state = state.copyWith(phase: CombatPhase.enemyTurn, enemy: enemy, log: log);
      _enemyAttacks();
    }
  }

  void _enemyAttacks() {
    final enemy = state.enemy!;
    final log = List<String>.from(state.log);
    final roll = roll2d6();
    if (roll > 6) {
      final dmg = (roll - 6) + enemy.extraDamage;
      log.add('🎲 ${enemy.name} : $roll > 6 → TOUCHÉ ! $dmg dégâts bruts.');
      _ref.read(playerStateProvider.notifier).takeDamage(dmg);
      final hp = _ref.read(playerStateProvider).currentHp;
      log.add('🩸 Vous : $hp PV restants.');
      if (_ref.read(playerStateProvider).isDead) {
        log.add('☠️ Vous êtes mort.');
        state = state.copyWith(phase: CombatPhase.playerDied, log: log);
        return;
      }
    } else {
      log.add('🎲 ${enemy.name} : $roll ≤ 6 → Manqué.');
    }
    state = state.copyWith(phase: CombatPhase.playerTurn, log: log);
  }

  String tryFriendlyReaction() {
    final enemy = state.enemy!;
    final p = [roll2d6(), roll2d6(), roll2d6()].reduce(max);
    final e = roll2d6();
    final log = List<String>.from(state.log);
    if (p < e) {
      log.add('🤝 Réaction Amicale ! Joueur ($p) < Ennemi ($e). Succès !');
      _ref.read(playerStateProvider.notifier).gainXp(1);
      state = state.copyWith(phase: CombatPhase.playerWon, log: log);
      return log.last;
    }
    log.add('❌ Réaction Amicale échouée ($p ≥ $e).');
    state = state.copyWith(log: log);
    return log.last;
  }

  void reset() => state = const CombatState();
}

final combatProvider =
    StateNotifierProvider<CombatNotifier, CombatState>((ref) {
  return CombatNotifier(ref);
});

// ── Sommeil ───────────────────────────────────────────────

class SleepResult {
  final bool dreamEncountered;
  final int healedHp;
  final int roll;
  const SleepResult({
    required this.dreamEncountered,
    required this.healedHp,
    required this.roll,
  });
}

SleepResult trySleep() {
  final roll = roll1d6();
  if (roll >= 5) return SleepResult(dreamEncountered: false, healedHp: roll2d6(), roll: roll);
  return SleepResult(dreamEncountered: true, healedHp: 0, roll: roll);
}
