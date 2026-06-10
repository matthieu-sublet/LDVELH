// ============================================================
//  providers/game_providers.dart  —  Riverpod State Management
// ============================================================
// Architecture :
//   gameDataProvider     → charge le JSON des paragraphes (async, une seule fois)
//   enemyDataProvider    → charge les définitions d'ennemis
//   playerStateProvider  → état mutable du joueur (StateNotifier)
//   currentParagraphProvider → paragraphe actuel (dérivé)
//   combatProvider       → moteur de combat (StateNotifier séparé)
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_models.dart';

final _rng = Random();

// ═══════════════════════════════════════════════════════════
//  1. CHARGEMENT DES DONNÉES JSON
// ═══════════════════════════════════════════════════════════

/// Charge et parse le fichier JSON principal (paragraphes + config)
final gameDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/data/game_structure.json');
  return jsonDecode(jsonString) as Map<String, dynamic>;
});

/// Map<paragraphId, Paragraph> prête à l'emploi
final paragraphsProvider = Provider<AsyncValue<Map<String, Paragraph>>>((ref) {
  return ref.watch(gameDataProvider).whenData((data) {
    final raw = data['paragraphs'] as Map<String, dynamic>;
    return raw.map((key, value) =>
        MapEntry(key, Paragraph.fromJson(value as Map<String, dynamic>)));
  });
});

/// Map<enemyId, Enemy>
final enemiesProvider = Provider<AsyncValue<Map<String, Enemy>>>((ref) {
  return ref.watch(gameDataProvider).whenData((data) {
    final raw = data['enemies'] as Map<String, dynamic>;
    return raw.map((key, value) =>
        MapEntry(key, Enemy.fromJson(value as Map<String, dynamic>)));
  });
});

/// Config de départ (starting_inventory, rules, etc.)
final gameConfigProvider = Provider<AsyncValue<Map<String, dynamic>>>((ref) {
  return ref.watch(gameDataProvider).whenData((data) =>
      data['game_config'] as Map<String, dynamic>);
});

// ═══════════════════════════════════════════════════════════
//  2. ÉTAT DU JOUEUR  (PlayerStateNotifier)
// ═══════════════════════════════════════════════════════════

class PlayerStateNotifier extends StateNotifier<PlayerState> {
  PlayerStateNotifier(PlayerState initial) : super(initial);

  // ── Navigation ────────────────────────────────────────────

  void navigateTo(String paragraphId) {
    state = state.copyWith(
      currentParagraphId: paragraphId,
      history: [...state.history, paragraphId],
    );
  }

  void goBack() {
    if (state.history.length <= 1) return;
    final newHistory = List<String>.from(state.history)..removeLast();
    state = state.copyWith(
      currentParagraphId: newHistory.last,
      history: newHistory,
    );
  }

  // ── Points de vie ─────────────────────────────────────────

  /// Applique des dégâts (tient compte de l'armure et du pourpoint)
  void takeDamage(int rawDamage, {bool bypassArmor = false}) {
    final reduction = bypassArmor ? 0 : state.armorReduction;
    final actualDamage = (rawDamage - reduction).clamp(0, 999);
    final newHp = (state.currentHp - actualDamage).clamp(0, state.maxHp + state.permanentHp);
    state = state.copyWith(currentHp: newHp);
  }

  /// Soigne le joueur (ne dépasse pas maxHp + permanentHp)
  void heal(int amount) {
    final cap = state.maxHp + state.permanentHp;
    final newHp = (state.currentHp + amount).clamp(0, cap);
    state = state.copyWith(currentHp: newHp);
  }

  /// Initialise les PV de départ (appelé depuis l'écran de création)
  void setStartingHp(int hp) {
    state = state.copyWith(maxHp: hp, currentHp: hp);
  }

  // ── Expérience ────────────────────────────────────────────

  void gainXp(int amount) {
    final newXp = state.experiencePoints + amount;
    final newPermHp = newXp ~/ 20;
    if (newPermHp > state.permanentHp) {
      // Nouveau point permanent gagné !
      final gained = newPermHp - state.permanentHp;
      state = state.copyWith(
        experiencePoints: newXp,
        permanentHp: newPermHp,
        currentHp: state.currentHp + gained, // Bonus immédiat
      );
    } else {
      state = state.copyWith(experiencePoints: newXp);
    }
  }

  // ── Inventaire ────────────────────────────────────────────

  void addItem(InventoryItem item) {
    if (state.hasItem(item.id)) return; // Pas de doublon
    state = state.copyWith(inventory: [...state.inventory, item]);
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      inventory: state.inventory.where((i) => i.id != itemId).toList(),
    );
  }

  void useConsumable(String itemId) {
    final idx = state.inventory.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final item = state.inventory[idx];
    if (item.usesRemaining <= 0) return;

    final updated = List<InventoryItem>.from(state.inventory);
    updated[idx] = item.copyWith(usesRemaining: item.usesRemaining - 1);

    if (item.effect == 'heal_2d6') {
      heal(roll2d6());
    } else if (item.effect == 'damage_10_no_roll') {
      // Géré côté combat
    }

    state = state.copyWith(inventory: updated);
  }

  // ── Bourse ────────────────────────────────────────────────

  void addGold(int amount) {
    state = state.copyWith(purse: state.purse.copyWith(
      goldPieces: state.purse.goldPieces + amount,
    ));
  }

  void spendGold(int amount) {
    final newGold = (state.purse.goldPieces - amount).clamp(0, 999999);
    state = state.copyWith(purse: state.purse.copyWith(goldPieces: newGold));
  }

  // ── Restauration depuis une sauvegarde ───────────────────

  void restoreFrom(PlayerState saved) {
    state = saved;
  }

  // ── Loot et ennemis vaincus ──────────────────────────────

  void markEnemyDefeated(String enemyId) {
    state = state.copyWith(
      defeatedEnemies: {...state.defeatedEnemies, enemyId},
    );
  }

  void markLootCollected(String paragraphId) {
    state = state.copyWith(
      collectedLoot: {...state.collectedLoot, paragraphId},
    );
  }

  bool isLootCollected(String paragraphId) =>
      state.collectedLoot.contains(paragraphId);

  // ── Mort / Réinitialisation ───────────────────────────────

  void resetForNewRun(List<InventoryItem> startingInventory) {
    // Conserve les ennemis vaincus (règle du livre)
    final oldDefeated = state.defeatedEnemies;
    state = PlayerState(
      maxHp: state.maxHp,         // PV recalculés avant d'appeler
      currentHp: state.maxHp,
      defeatedEnemies: oldDefeated,
      inventory: startingInventory,
      currentParagraphId: 'intro',
    );
  }
}

// ─── Provider principal du joueur ─────────────────────────

final playerStateProvider =
    StateNotifierProvider<PlayerStateNotifier, PlayerState>((ref) {
  // État par défaut — sera surchargé après init des PV
  return PlayerStateNotifier(const PlayerState(
    maxHp: 0,
    currentHp: 0,
    currentParagraphId: 'hp_setup',
    inventory: [],
  ));
});

// ─── Paragraphe actuel ────────────────────────────────────

final currentParagraphProvider = Provider<Paragraph?>((ref) {
  final paragraphsAsync = ref.watch(paragraphsProvider);
  final currentId = ref.watch(playerStateProvider).currentParagraphId;

  return paragraphsAsync.whenOrNull(
    data: (paragraphs) => paragraphs[currentId],
  );
});

// ═══════════════════════════════════════════════════════════
//  3. MOTEUR DE COMBAT  (CombatNotifier)
// ═══════════════════════════════════════════════════════════

enum CombatPhase { idle, playerTurn, enemyTurn, playerWon, playerDied }

class CombatState {
  final CombatPhase phase;
  final Enemy? enemy;
  final String lastRollDescription;
  final List<String> log;
  final String? winParagraph;
  final String? deathParagraph;

  const CombatState({
    this.phase = CombatPhase.idle,
    this.enemy,
    this.lastRollDescription = '',
    this.log = const [],
    this.winParagraph,
    this.deathParagraph,
  });

  CombatState copyWith({
    CombatPhase? phase,
    Enemy? enemy,
    String? lastRollDescription,
    List<String>? log,
    String? winParagraph,
    String? deathParagraph,
  }) {
    return CombatState(
      phase: phase ?? this.phase,
      enemy: enemy ?? this.enemy,
      lastRollDescription: lastRollDescription ?? this.lastRollDescription,
      log: log ?? this.log,
      winParagraph: winParagraph ?? this.winParagraph,
      deathParagraph: deathParagraph ?? this.deathParagraph,
    );
  }
}

class CombatNotifier extends StateNotifier<CombatState> {
  final Ref _ref;

  CombatNotifier(this._ref) : super(const CombatState());

  // ── Démarre un combat ─────────────────────────────────────

  void startCombat(CombatData data, Enemy enemyTemplate) {
    final enemy = enemyTemplate.clone();
    state = CombatState(
      phase: (data.playerStrikesFirst ?? true)
          ? CombatPhase.playerTurn
          : CombatPhase.enemyTurn,
      enemy: enemy,
      winParagraph: data.onWinParagraph,
      deathParagraph: data.onDeathParagraph,
      log: ['⚔️ Combat contre ${enemy.name} commencé !'],
    );

    // Si l'ennemi frappe en premier, résoudre son attaque immédiatement
    if (!data.playerStrikesFirst) {
      _resolveEnemyAttack();
    }
  }

  // ── Tour du joueur ────────────────────────────────────────

  /// Lance les dés pour l'attaque du joueur, applique les dommages à l'ennemi.
  /// Retourne la description du résultat.
  String playerAttacks() {
    if (state.phase != CombatPhase.playerTurn) return '';
    final player = _ref.read(playerStateProvider);
    final enemy = state.enemy!;

    final roll = roll2d6();
    final threshold = player.attackThreshold; // 4 avec E.J., 6 sinon
    final log = List<String>.from(state.log);

    String description;
    if (roll > threshold) {
      // Touché !
      int damage = (roll - threshold) + player.weaponBonusDamage;
      description = '🎲 Vous lancez $roll (seuil : $threshold) → TOUCHÉ ! '
          '${(roll - threshold)} + ${player.weaponBonusDamage} (arme) = $damage dégâts';
      _applyDamageToEnemy(damage, enemy, log, description);
    } else {
      description = '🎲 Vous lancez $roll (seuil : $threshold) → Manqué.';
      log.add(description);
      state = state.copyWith(
        phase: CombatPhase.enemyTurn,
        enemy: enemy,
        lastRollDescription: description,
        log: log,
      );
      _resolveEnemyAttack();
    }

    return description;
  }

  /// Utilise Doigt de Feu (10 dégâts, sans lancer de dés)
  void useMagicFinger(String itemId) {
    if (state.phase != CombatPhase.playerTurn) return;
    final player = _ref.read(playerStateProvider);

    _ref.read(playerStateProvider.notifier).useConsumable(itemId);
    final enemy = state.enemy!;
    final log = List<String>.from(state.log);
    const damage = 10;
    const description = '✨ Doigt de Feu ! 10 dégâts assurés.';

    _applyDamageToEnemy(damage, enemy, log, description);
  }

  void _applyDamageToEnemy(int damage, Enemy enemy, List<String> log, String desc) {
    log.add(desc);
    final enemyCopy = enemy.clone();

    // L'armure encaisse d'abord
    if (enemyCopy.currentArmor > 0) {
      final armorDamage = damage.clamp(0, enemyCopy.currentArmor);
      enemyCopy.currentArmor -= armorDamage;
      damage -= armorDamage;
      log.add('🛡️ Armure ennemie absorbe $armorDamage pts. (Armure restante : ${enemyCopy.currentArmor})');
    }

    if (damage > 0) {
      enemyCopy.currentHp -= damage;
      log.add('💀 ${enemyCopy.name} : ${enemyCopy.currentHp} PV restants.');
    }

    if (enemyCopy.isDead || enemyCopy.isKnockedOut) {
      log.add('🏆 ${enemyCopy.name} est vaincu !');
      state = state.copyWith(
        phase: CombatPhase.playerWon,
        enemy: enemyCopy,
        log: log,
        lastRollDescription: desc,
      );
      // Gain d'XP
      _ref.read(playerStateProvider.notifier).gainXp(1);
    } else {
      state = state.copyWith(
        phase: CombatPhase.enemyTurn,
        enemy: enemyCopy,
        log: log,
        lastRollDescription: desc,
      );
      _resolveEnemyAttack();
    }
  }

  // ── Tour de l'ennemi (auto-résolu) ───────────────────────

  void _resolveEnemyAttack() {
    final enemy = state.enemy!;
    final player = _ref.read(playerStateProvider);
    final log = List<String>.from(state.log);

    final roll = roll2d6();
    final threshold = enemy.attackThreshold;

    String description;
    if (roll > threshold) {
      int rawDamage = (roll - threshold) + enemy.bonusDamage;
      description = '🎲 ${enemy.name} lance $roll (seuil : $threshold) → TOUCHÉ ! '
          '$rawDamage dégâts bruts.';
      log.add(description);

      // Le pourpoint en peau de dragon réduit les dégâts (sauf si contourné)
      final bypassArmor = enemy.playerCoatBypassed;
      _ref.read(playerStateProvider.notifier).takeDamage(rawDamage, bypassArmor: bypassArmor);

      final actualDamage = bypassArmor
          ? rawDamage
          : (rawDamage - player.armorReduction).clamp(0, 999);
      log.add('🩸 Vous perdez $actualDamage PV. (PV restants : ${player.currentHp - actualDamage})');

    } else {
      description = '🎲 ${enemy.name} lance $roll (seuil : $threshold) → Manqué.';
      log.add(description);
    }

    // Vérifier mort/KO du joueur
    final updatedPlayer = _ref.read(playerStateProvider);
    if (updatedPlayer.isDead) {
      log.add('☠️ Vous êtes mort.');
      state = state.copyWith(
        phase: CombatPhase.playerDied,
        log: log,
        lastRollDescription: description,
      );
    } else {
      state = state.copyWith(
        phase: CombatPhase.playerTurn,
        log: log,
        lastRollDescription: description,
      );
    }
  }

  // ── Réaction Amicale ──────────────────────────────────────

  String tryFriendlyReaction() {
    final playerRoll1 = roll2d6();
    final playerRoll2 = roll2d6();
    final playerRoll3 = roll2d6();
    final enemyRoll = roll2d6();
    final bestPlayerRoll = [playerRoll1, playerRoll2, playerRoll3].reduce(max);

    if (bestPlayerRoll < enemyRoll) {
      state = state.copyWith(phase: CombatPhase.playerWon);
      _ref.read(playerStateProvider.notifier).gainXp(1);
      return '🤝 Réaction Amicale ! Joueur ($bestPlayerRoll) < Ennemi ($enemyRoll). Succès !';
    } else {
      return '❌ Réaction Amicale échouée. Joueur ($bestPlayerRoll) ≥ Ennemi ($enemyRoll). Le combat continue.';
    }
  }

  // ── Corruption ────────────────────────────────────────────

  String tryCorruption(int goldOffered) {
    _ref.read(playerStateProvider.notifier).spendGold(goldOffered);
    final roll = roll2d6();
    if (roll >= 8) {
      state = state.copyWith(phase: CombatPhase.playerWon);
      _ref.read(playerStateProvider.notifier).gainXp(1);
      return '💰 Corruption réussie ! (Lancé : $roll ≥ 8). Vous avez dépensé $goldOffered P.O.';
    } else {
      return '❌ Corruption refusée. (Lancé : $roll < 8). $goldOffered P.O. perdus quand même.';
    }
  }

  void reset() {
    state = const CombatState();
  }
}

final combatProvider =
    StateNotifierProvider<CombatNotifier, CombatState>((ref) {
  return CombatNotifier(ref);
});

// ═══════════════════════════════════════════════════════════
//  4. UTILITAIRES DE DÉS
// ═══════════════════════════════════════════════════════════

int roll1d6() => _rng.nextInt(6) + 1;
int roll2d6() => roll1d6() + roll1d6();

/// Lancer les PV initiaux (2d6 × 4), 3 tentatives, garder le max
int rollStartingHp() {
  int best = 0;
  for (int i = 0; i < 3; i++) {
    final roll = roll2d6() * 4;
    if (roll > best) best = roll;
  }
  return best;
}

/// Sommeil : lance 1d6. 1-4 = Rêve, 5-6 = sommeil réparateur
SleepResult trySleep() {
  final roll = roll1d6();
  if (roll >= 5) {
    final healed = roll2d6();
    return SleepResult(dreamEncountered: false, healedHp: healed, roll: roll);
  } else {
    return SleepResult(dreamEncountered: true, healedHp: 0, roll: roll);
  }
}

class SleepResult {
  final bool dreamEncountered;
  final int healedHp;
  final int roll;
  const SleepResult({required this.dreamEncountered, required this.healedHp, required this.roll});
}
