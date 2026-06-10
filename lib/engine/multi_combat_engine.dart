// ============================================================
//  engine/multi_combat_engine.dart — Combats multiples
// ============================================================
// Gère les séquences de combats contre N ennemis successifs :
//   • Molosses ×2 (§28, §130)
//   • Zombies ×6 (§44)  — règle spéciale : tuer seulement sur 9-12
//   • Gardes ×2 (§86, §95)
// ============================================================

import 'dart:math';
import '../models/game_models.dart';
import '../providers/game_providers.dart';

final _rng = Random();

enum MultiCombatPhase {
  idle,
  playerTurn,
  enemyTurn,
  betweenEnemies, // Court repos entre deux ennemis
  allWon,
  playerDied,
}

class MultiCombatState {
  final MultiCombatPhase phase;
  final List<Enemy> enemies;
  final int currentEnemyIndex;
  final List<String> log;
  final String? winParagraph;
  final String? deathParagraph;
  final bool zombieSpecialRule; // Tuer seulement sur 9-12
  final String lastRollDescription;

  const MultiCombatState({
    this.phase = MultiCombatPhase.idle,
    this.enemies = const [],
    this.currentEnemyIndex = 0,
    this.log = const [],
    this.winParagraph,
    this.deathParagraph,
    this.zombieSpecialRule = false,
    this.lastRollDescription = '',
  });

  Enemy? get currentEnemy =>
      currentEnemyIndex < enemies.length ? enemies[currentEnemyIndex] : null;

  int get totalEnemies => enemies.length;
  int get enemiesDefeated => enemies.where((e) => e.isDead || e.isKnockedOut).length;

  MultiCombatState copyWith({
    MultiCombatPhase? phase,
    List<Enemy>? enemies,
    int? currentEnemyIndex,
    List<String>? log,
    String? winParagraph,
    String? deathParagraph,
    bool? zombieSpecialRule,
    String? lastRollDescription,
  }) {
    return MultiCombatState(
      phase: phase ?? this.phase,
      enemies: enemies ?? this.enemies,
      currentEnemyIndex: currentEnemyIndex ?? this.currentEnemyIndex,
      log: log ?? this.log,
      winParagraph: winParagraph ?? this.winParagraph,
      deathParagraph: deathParagraph ?? this.deathParagraph,
      zombieSpecialRule: zombieSpecialRule ?? this.zombieSpecialRule,
      lastRollDescription: lastRollDescription ?? this.lastRollDescription,
    );
  }
}

class MultiCombatEngine {
  MultiCombatState _state = const MultiCombatState();
  MultiCombatState get state => _state;

  // Callback pour mettre à jour l'état du joueur
  final void Function(int damage, {bool bypassArmor}) onPlayerTakeDamage;
  final void Function(int xp) onGainXp;
  final PlayerState Function() getPlayerState;

  MultiCombatEngine({
    required this.onPlayerTakeDamage,
    required this.onGainXp,
    required this.getPlayerState,
  });

  // ── Démarrage ─────────────────────────────────────────────

  void start({
    required List<Enemy> enemyList,
    required bool playerFirst,
    required String onWin,
    required String onDeath,
    bool zombieRule = false,
  }) {
    final log = ['⚔️ Combat multiple : ${enemyList.map((e) => e.name).join(', ')}'];

    _state = MultiCombatState(
      phase: playerFirst ? MultiCombatPhase.playerTurn : MultiCombatPhase.enemyTurn,
      enemies: enemyList.map((e) => e.clone()).toList(),
      currentEnemyIndex: 0,
      log: log,
      winParagraph: onWin,
      deathParagraph: onDeath,
      zombieSpecialRule: zombieRule,
    );

    if (!playerFirst) _resolveCurrentEnemyAttack();
  }

  // ── Attaque du joueur ─────────────────────────────────────

  String playerAttacks() {
    if (_state.phase != MultiCombatPhase.playerTurn) return '';
    final enemy = _state.currentEnemy;
    if (enemy == null) return '';

    final player = getPlayerState();
    final roll = roll2d6();
    final threshold = player.attackThreshold;
    final log = List<String>.from(_state.log);

    String desc;
    if (roll > threshold) {
      int damage = (roll - threshold) + player.weaponBonusDamage;

      // Règle Zombie : effet nul si résultat < 9
      if (_state.zombieSpecialRule && roll < 9) {
        desc = '🎲 $roll → touché mais le Zombie est insensible ! (il faut 9-12 pour le tuer)';
        log.add(desc);
        _state = _state.copyWith(
          phase: MultiCombatPhase.enemyTurn,
          log: log,
          lastRollDescription: desc,
        );
        _resolveCurrentEnemyAttack();
        return desc;
      }

      desc = '🎲 $roll (seuil $threshold) → TOUCHÉ ! $damage dégâts.';
      log.add(desc);
      _applyDamageToCurrentEnemy(damage, log);
    } else {
      desc = '🎲 $roll (seuil $threshold) → Manqué.';
      log.add(desc);
      _state = _state.copyWith(
        phase: MultiCombatPhase.enemyTurn,
        log: log,
        lastRollDescription: desc,
      );
      _resolveCurrentEnemyAttack();
    }
    return desc;
  }

  void _applyDamageToCurrentEnemy(int damage, List<String> log) {
    final enemies = List<Enemy>.from(_state.enemies);
    final idx = _state.currentEnemyIndex;
    final enemy = enemies[idx].clone();

    if (enemy.currentArmor > 0) {
      final ab = damage.clamp(0, enemy.currentArmor);
      enemy.currentArmor -= ab;
      damage -= ab;
      log.add('🛡️ Armure absorbe $ab pts → armure restante : ${enemy.currentArmor}');
    }
    if (damage > 0) {
      enemy.currentHp -= damage;
      log.add('💀 ${enemy.name} : ${enemy.currentHp} PV');
    }
    enemies[idx] = enemy;

    if (enemy.isDead || enemy.isKnockedOut) {
      log.add('✅ ${enemy.name} vaincu !');
      onGainXp(1);

      // Ennemi suivant ?
      final nextIdx = idx + 1;
      if (nextIdx >= enemies.length) {
        log.add('🏆 Tous les ennemis sont vaincus !');
        _state = _state.copyWith(
          phase: MultiCombatPhase.allWon,
          enemies: enemies,
          currentEnemyIndex: nextIdx,
          log: log,
        );
      } else {
        log.add('⚔️ Ennemi suivant : ${enemies[nextIdx].name} (${enemies[nextIdx].currentHp} PV)');
        _state = _state.copyWith(
          phase: MultiCombatPhase.betweenEnemies,
          enemies: enemies,
          currentEnemyIndex: nextIdx,
          log: log,
        );
      }
    } else {
      _state = _state.copyWith(
        phase: MultiCombatPhase.enemyTurn,
        enemies: enemies,
        log: log,
      );
      _resolveCurrentEnemyAttack();
    }
  }

  // ── Continuer après victoire intermédiaire ────────────────

  void continueToNextEnemy() {
    if (_state.phase != MultiCombatPhase.betweenEnemies) return;
    _state = _state.copyWith(phase: MultiCombatPhase.playerTurn);
  }

  // ── Attaque de l'ennemi courant (auto-résolu) ─────────────

  void _resolveCurrentEnemyAttack() {
    final enemy = _state.currentEnemy;
    if (enemy == null) return;

    final player = getPlayerState();
    final roll = roll2d6();
    final threshold = enemy.attackThreshold;
    final log = List<String>.from(_state.log);

    String desc;
    if (roll > threshold) {
      int rawDmg = (roll - threshold) + enemy.bonusDamage;
      desc = '🎲 ${enemy.name} lance $roll (seuil $threshold) → TOUCHÉ ! $rawDmg dégâts bruts.';
      log.add(desc);
      onPlayerTakeDamage(rawDmg, bypassArmor: enemy.playerCoatBypassed);

      final actualDmg = enemy.playerCoatBypassed
          ? rawDmg
          : (rawDmg - player.armorReduction).clamp(0, 999);
      log.add('🩸 Vous perdez $actualDmg PV.');
    } else {
      desc = '🎲 ${enemy.name} lance $roll (seuil $threshold) → Manqué.';
      log.add(desc);
    }

    // Vérifier état joueur après mise à jour
    final updatedPlayer = getPlayerState();
    if (updatedPlayer.isDead) {
      log.add('☠️ Vous êtes mort.');
      _state = _state.copyWith(
        phase: MultiCombatPhase.playerDied,
        log: log,
        lastRollDescription: desc,
      );
    } else {
      _state = _state.copyWith(
        phase: MultiCombatPhase.playerTurn,
        log: log,
        lastRollDescription: desc,
      );
    }
  }

  // ── Réaction Amicale ──────────────────────────────────────

  String tryFriendlyReaction() {
    final enemy = _state.currentEnemy;
    if (enemy == null) return '';

    final p1 = roll2d6(), p2 = roll2d6(), p3 = roll2d6();
    final best = [p1, p2, p3].reduce(max);
    final er = roll2d6();
    final log = List<String>.from(_state.log);

    String result;
    if (best < er) {
      result = '🤝 Réaction Amicale ! Joueur ($best) < Ennemi ($er) → Succès !';
      log.add(result);
      // Traiter comme victoire sur cet ennemi
      _applyDamageToCurrentEnemy(enemy.currentHp + 999, log);
      onGainXp(1);
    } else {
      result = '❌ Réaction échouée. Joueur ($best) ≥ Ennemi ($er). Combat continue.';
      log.add(result);
      _state = _state.copyWith(log: log);
    }
    return result;
  }

  void reset() {
    _state = const MultiCombatState();
  }
}
