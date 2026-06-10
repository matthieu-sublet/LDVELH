// ============================================================
//  widgets/multi_combat_overlay.dart
//  Overlay pour combats contre N ennemis successifs
//  (Molosses ×2, Zombies ×6, Gardes ×2, etc.)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/multi_combat_engine.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';

// ── Provider du moteur multi-combat ──────────────────────────

final multiCombatEngineProvider =
    StateNotifierProvider<_MultiEngineNotifier, MultiCombatState>((ref) {
  return _MultiEngineNotifier(ref);
});

class _MultiEngineNotifier extends StateNotifier<MultiCombatState> {
  final Ref _ref;
  late final MultiCombatEngine _engine;

  _MultiEngineNotifier(this._ref) : super(const MultiCombatState()) {
    _engine = MultiCombatEngine(
      onPlayerTakeDamage: (dmg, {bypassArmor = false}) {
        _ref.read(playerStateProvider.notifier).takeDamage(dmg, bypassArmor: bypassArmor);
      },
      onGainXp: (xp) => _ref.read(playerStateProvider.notifier).gainXp(xp),
      getPlayerState: () => _ref.read(playerStateProvider),
    );
  }

  void start({
    required List<Enemy> enemies,
    required bool playerFirst,
    required String onWin,
    required String onDeath,
    bool zombieRule = false,
  }) {
    _engine.start(
      enemyList: enemies,
      playerFirst: playerFirst,
      onWin: onWin,
      onDeath: onDeath,
      zombieRule: zombieRule,
    );
    state = _engine.state;
  }

  void playerAttacks() {
    _engine.playerAttacks();
    state = _engine.state;
  }

  void useMagicFinger(String itemId) {
    _ref.read(playerStateProvider.notifier).useConsumable(itemId);
    // 10 dégâts directs sur l'ennemi courant
    final enemy = _engine.state.currentEnemy;
    if (enemy != null) {
      final log = List<String>.from(_engine.state.log)
        ..add('✨ Doigt de Feu → 10 dégâts garantis !');
      _engine.playerAttacks(); // TODO: implémenter _applyDirectDamage public
    }
    state = _engine.state;
  }

  void tryFriendlyReaction() {
    _engine.tryFriendlyReaction();
    state = _engine.state;
  }

  void continueToNext() {
    _engine.continueToNextEnemy();
    state = _engine.state;
  }

  void reset() {
    _engine.reset();
    state = _engine.state;
  }
}

// ══════════════════════════════════════════════════════════
//  Widget principal
// ══════════════════════════════════════════════════════════

class MultiCombatOverlay extends ConsumerWidget {
  final void Function(bool won, String targetParagraph) onCombatEnd;

  const MultiCombatOverlay({super.key, required this.onCombatEnd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(multiCombatEngineProvider);
    final player = ref.watch(playerStateProvider);
    final notifier = ref.read(multiCombatEngineProvider.notifier);

    // ── Fins de combat ─────────────────────────────────────
    if (state.phase == MultiCombatPhase.allWon && state.winParagraph != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEndDialog(context, won: true, ref: ref,
            enemyNames: state.enemies.map((e) => e.name).toSet().join(', '),
            onContinue: () => onCombatEnd(true, state.winParagraph!));
      });
    }
    if (state.phase == MultiCombatPhase.playerDied && state.deathParagraph != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEndDialog(context, won: false, ref: ref,
            enemyNames: '',
            onContinue: () => onCombatEnd(false, state.deathParagraph!));
      });
    }

    return Material(
      color: Colors.black.withOpacity(0.92),
      child: SafeArea(
        child: Column(
          children: [
            // ── En-tête : progression des ennemis ──────────
            _EnemyProgressBar(
              enemies: state.enemies,
              currentIndex: state.currentEnemyIndex,
            ),

            // ── PV joueur ──────────────────────────────────
            _PlayerHpRow(currentHp: player.currentHp, maxHp: player.maxHp),

            // ── Ennemi courant ─────────────────────────────
            if (state.currentEnemy != null)
              _CurrentEnemyCard(enemy: state.currentEnemy!),

            // ── Log ───────────────────────────────────────
            Expanded(child: _CombatScrollLog(log: state.log)),

            // ── Phase : entre deux ennemis ─────────────────
            if (state.phase == MultiCombatPhase.betweenEnemies)
              _BetweenEnemiesBar(
                nextEnemy: state.currentEnemy,
                onContinue: notifier.continueToNext,
              ),

            // ── Actions joueur ────────────────────────────
            if (state.phase == MultiCombatPhase.playerTurn)
              _CombatActions(
                player: player,
                onAttack: notifier.playerAttacks,
                onFriendlyReaction: notifier.tryFriendlyReaction,
                onMagic: (id) => notifier.useMagicFinger(id),
              ),

            if (state.phase == MultiCombatPhase.enemyTurn)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('⌛ L\'ennemi attaque...',
                    style: TextStyle(fontFamily: 'Cinzel',
                        color: GraalTheme.danger, fontSize: 16)),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEndDialog(BuildContext context,
      {required bool won, required WidgetRef ref,
       required String enemyNames, required VoidCallback onContinue}) {
    if (!context.mounted) return;
    // Éviter doubles dialogues
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => won
          ? _VictoryDialog(enemyNames: enemyNames, onContinue: () {
              Navigator.of(context).pop();
              ref.read(multiCombatEngineProvider.notifier).reset();
              onContinue();
            })
          : _DeathDialog(onContinue: () {
              Navigator.of(context).pop();
              ref.read(multiCombatEngineProvider.notifier).reset();
              onContinue();
            }),
    );
  }
}

// ── Sous-widgets ───────────────────────────────────────────

class _EnemyProgressBar extends StatelessWidget {
  final List<Enemy> enemies;
  final int currentIndex;
  const _EnemyProgressBar({required this.enemies, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GraalTheme.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${enemies.length > 1 ? "Combat multiple (${enemies.length} ennemis)" : "Combat"}',
            style: const TextStyle(
              fontFamily: 'Cinzel', color: GraalTheme.amber, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Row(
            children: enemies.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final isDead = e.isDead || e.isKnockedOut;
              final isCurrent = i == currentIndex;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDead
                        ? GraalTheme.surface
                        : isCurrent
                            ? const Color(0xFF2A0000)
                            : const Color(0xFF1A1A00),
                    border: Border.all(
                      color: isDead
                          ? GraalTheme.divider
                          : isCurrent
                              ? GraalTheme.danger
                              : GraalTheme.amber.withOpacity(0.4),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isDead ? '💀' : isCurrent ? '⚔️' : '⏳',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.name.split(' ').first,
                        style: TextStyle(
                          fontFamily: 'Crimson Text',
                          fontSize: 11,
                          color: isDead ? GraalTheme.textDim : GraalTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isDead)
                        Text(
                          '${e.currentHp} PV',
                          style: TextStyle(
                            fontFamily: 'Crimson Text',
                            fontSize: 11,
                            color: isCurrent ? GraalTheme.dangerLight : GraalTheme.textDim,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PlayerHpRow extends StatelessWidget {
  final int currentHp, maxHp;
  const _PlayerHpRow({required this.currentHp, required this.maxHp});

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final col = ratio > .5 ? GraalTheme.success : ratio > .25 ? GraalTheme.amber : GraalTheme.dangerLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Text('PIP ', style: TextStyle(fontFamily:'Cinzel', color:GraalTheme.textSecondary, fontSize:11)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: ratio, backgroundColor: GraalTheme.surfaceVariant, color: col, minHeight: 8),
        )),
        const SizedBox(width: 8),
        Text('$currentHp/$maxHp', style: TextStyle(fontFamily:'Crimson Text', color:col, fontSize:14, fontWeight:FontWeight.bold)),
      ]),
    );
  }
}

class _CurrentEnemyCard extends StatelessWidget {
  final Enemy enemy;
  const _CurrentEnemyCard({required this.enemy});

  @override
  Widget build(BuildContext context) {
    final ratio = (enemy.currentHp / enemy.maxHp).clamp(0.0, 1.0);
    final col = ratio > .5 ? GraalTheme.danger : ratio > .25 ? GraalTheme.amber : GraalTheme.amberLight;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0000),
        border: Border.all(color: GraalTheme.danger.withOpacity(.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('⚔️ ${enemy.name}', style: const TextStyle(
            fontFamily:'Cinzel', color:GraalTheme.amberLight, fontSize:16, fontWeight:FontWeight.bold)),
          Text('${enemy.currentHp} / ${enemy.maxHp} PV',
            style: TextStyle(fontFamily:'Crimson Text', color:col, fontSize:14, fontWeight:FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: ratio, backgroundColor: GraalTheme.surfaceVariant, color: col, minHeight: 6),
        ),
        if (enemy.currentArmor > 0) ...[
          const SizedBox(height: 4),
          Text('🛡️ Armure : ${enemy.currentArmor} pts restants',
            style: const TextStyle(fontFamily:'Crimson Text', color:GraalTheme.textSecondary, fontSize:13)),
        ],
        if (enemy.specialNotes != null && enemy.specialNotes!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('⚠️ ${enemy.specialNotes}',
            style: const TextStyle(fontFamily:'Crimson Text', color:GraalTheme.amber, fontSize:12, fontStyle:FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _BetweenEnemiesBar extends StatelessWidget {
  final Enemy? nextEnemy;
  final VoidCallback onContinue;
  const _BetweenEnemiesBar({required this.nextEnemy, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text(
          nextEnemy != null ? '✅ Ennemi vaincu ! Prochain : ${nextEnemy!.name}' : '✅ Tous vaincus !',
          style: const TextStyle(fontFamily:'Cinzel', color:GraalTheme.success, fontSize:15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF001A00),
              foregroundColor: GraalTheme.success,
              side: const BorderSide(color: GraalTheme.success),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('⚔️  Combattre l\'ennemi suivant'),
          ),
        ),
      ]),
    );
  }
}

class _CombatScrollLog extends StatefulWidget {
  final List<String> log;
  const _CombatScrollLog({required this.log});
  @override State<_CombatScrollLog> createState() => _CombatScrollLogState();
}
class _CombatScrollLogState extends State<_CombatScrollLog> {
  final _sc = ScrollController();
  @override void didUpdateWidget(_CombatScrollLog old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: GraalTheme.surface, border: Border.all(color: GraalTheme.divider),
      borderRadius: BorderRadius.circular(4)),
    child: ListView.builder(
      controller: _sc, itemCount: widget.log.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(widget.log[i], style: const TextStyle(
          fontFamily:'Crimson Text', color:GraalTheme.textPrimary, fontSize:14, height:1.4)),
      )),
  );
}

class _CombatActions extends StatelessWidget {
  final PlayerState player;
  final VoidCallback onAttack, onFriendlyReaction;
  final void Function(String) onMagic;
  const _CombatActions({required this.player, required this.onAttack,
    required this.onFriendlyReaction, required this.onMagic});

  @override Widget build(BuildContext context) {
    final mr = player.inventory.firstWhere((i) => i.id == 'fire_finger_right',
      orElse: () => InventoryItem(id:'_none',name:'',type:ItemType.magic,description:''));
    final ml = player.inventory.firstWhere((i) => i.id == 'fire_finger_left',
      orElse: () => InventoryItem(id:'_none',name:'',type:ItemType.magic,description:''));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: [
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: onAttack,
          icon: const Icon(Icons.gavel, size: 18),
          label: Text('⚔️  Attaquer avec ${player.equippedWeapon?.name ?? "poings"}'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF1A0E00),
            foregroundColor: GraalTheme.amber,
            side: const BorderSide(color: GraalTheme.amber)),
        )),
        const SizedBox(height: 6),
        Row(children: [
          if (mr.id != '_none' && mr.usesRemaining > 0)
            Expanded(child: _SmallBtn('✨ D.Feu D (${mr.usesRemaining})', GraalTheme.magic, () => onMagic('fire_finger_right'))),
          if (mr.id != '_none' && mr.usesRemaining > 0 && ml.id != '_none' && ml.usesRemaining > 0)
            const SizedBox(width: 6),
          if (ml.id != '_none' && ml.usesRemaining > 0)
            Expanded(child: _SmallBtn('✨ D.Feu G (${ml.usesRemaining})', GraalTheme.magic, () => onMagic('fire_finger_left'))),
          if ((mr.id == '_none' || mr.usesRemaining == 0) && (ml.id == '_none' || ml.usesRemaining == 0))
            const SizedBox.shrink(),
        ]),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: OutlinedButton(
          onPressed: onFriendlyReaction,
          style: OutlinedButton.styleFrom(
            foregroundColor: GraalTheme.success,
            side: const BorderSide(color: GraalTheme.success),
            padding: const EdgeInsets.symmetric(vertical: 10)),
          child: const Text('🤝 Réaction Amicale (3 lancers joueur < 1 ennemi)'),
        )),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _SmallBtn(this.label, this.color, this.onTap);
  @override Widget build(BuildContext ctx) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: color, side: BorderSide(color: color),
      padding: const EdgeInsets.symmetric(vertical: 10)),
    child: Text(label, style: TextStyle(fontFamily:'Crimson Text', color:color, fontSize:12)));
}

class _VictoryDialog extends StatelessWidget {
  final String enemyNames; final VoidCallback onContinue;
  const _VictoryDialog({required this.enemyNames, required this.onContinue});
  @override Widget build(BuildContext context) => AlertDialog(
    backgroundColor: GraalTheme.surfaceVariant,
    title: const Text('🏆 Victoire !', style: TextStyle(fontFamily:'Cinzel', color:GraalTheme.amberLight, fontSize:22)),
    content: Text('Tous les ennemis sont vaincus.\n\n+${enemyNames.split(',').length} Point(s) d\'Expérience.',
      style: const TextStyle(fontFamily:'Crimson Text', color:GraalTheme.textPrimary, fontSize:17)),
    actions: [ElevatedButton(onPressed: onContinue, child: const Text('Continuer'))],
  );
}

class _DeathDialog extends StatelessWidget {
  final VoidCallback onContinue;
  const _DeathDialog({required this.onContinue});
  @override Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF1A0000),
    title: const Text('☠️  Vous êtes mort.', style: TextStyle(fontFamily:'Cinzel', color:GraalTheme.dangerLight, fontSize:22)),
    content: const Text('Le combat vous a été fatal.\n\nVos ennemis vaincus restent morts lors de votre prochaine tentative.',
      style: TextStyle(fontFamily:'Crimson Text', color:GraalTheme.textPrimary, fontSize:17)),
    actions: [ElevatedButton(onPressed: onContinue,
      style: ElevatedButton.styleFrom(backgroundColor: GraalTheme.danger, foregroundColor: Colors.white),
      child: const Text('Recommencer'))],
  );
}
