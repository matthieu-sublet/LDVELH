// ============================================================
//  widgets/combat_overlay.dart  —  Interface de combat
// ============================================================
// Affiché en surcouche sur le texte pendant un combat actif.
// Gère : lancer de dés, affichage log, actions spéciales.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';

class CombatOverlay extends ConsumerWidget {
  final void Function(bool won, String targetParagraph) onCombatEnd;

  const CombatOverlay({super.key, required this.onCombatEnd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combat = ref.watch(combatProvider);
    final player = ref.watch(playerStateProvider);
    final enemy = combat.enemy;

    // ── Fin de combat ─────────────────────────────────────
    if (combat.phase == CombatPhase.playerWon && combat.winParagraph != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _VictoryDialog(
            enemyName: enemy?.name ?? 'l\'ennemi',
            onContinue: () {
              Navigator.of(context).pop();
              onCombatEnd(true, combat.winParagraph!);
            },
          ),
        );
      });
    }

    if (combat.phase == CombatPhase.playerDied && combat.deathParagraph != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DeathDialog(
            onContinue: () {
              Navigator.of(context).pop();
              onCombatEnd(false, combat.deathParagraph!);
            },
          ),
        );
      });
    }

    if (enemy == null) return const SizedBox.shrink();

    return Material(
      color: Colors.black.withOpacity(0.90),
      child: SafeArea(
        child: Column(
          children: [
            // ─ En-tête ennemi ───────────────────────────
            _EnemyHeader(enemy: enemy),

            // ─ PV du joueur ─────────────────────────────
            _PlayerHpBar(currentHp: player.currentHp, maxHp: player.maxHp),

            // ─ Log du combat ────────────────────────────
            Expanded(
              child: _CombatLog(log: combat.log),
            ),

            // ─ Actions du joueur ────────────────────────
            if (combat.phase == CombatPhase.playerTurn)
              _PlayerActions(
                player: player,
                onAttack: () => ref.read(combatProvider.notifier).playerAttacks(),
                onMagic: (id) => ref.read(combatProvider.notifier).useMagicFinger(id),
                onFriendlyReaction: () {
                  final result = ref.read(combatProvider.notifier).tryFriendlyReaction();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                },
                onCorruption: (paragraph) {
                  if (paragraph.corruptionTier == null) return;
                  final cost = const {1: 100, 2: 500, 3: 1000, 4: 10000}[paragraph.corruptionTier!]!;
                  if (!player.hasGold(cost)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Or insuffisant pour corrompre.')),
                    );
                    return;
                  }
                  final result = ref.read(combatProvider.notifier).tryCorruption(cost);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                },
              ),

            if (combat.phase == CombatPhase.enemyTurn)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  '⌛ L\'ennemi attaque...',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: GraalTheme.danger,
                    fontSize: 16,
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Sous-widgets ──────────────────────────────────────────

class _EnemyHeader extends StatelessWidget {
  final Enemy enemy;
  const _EnemyHeader({required this.enemy});

  @override
  Widget build(BuildContext context) {
    final ratio = enemy.currentHp / enemy.maxHp;
    final hpColor = ratio > 0.5
        ? GraalTheme.danger
        : ratio > 0.25
            ? GraalTheme.amber
            : GraalTheme.amberLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GraalTheme.divider)),
      ),
      child: Column(
        children: [
          Text(
            '⚔️  ${enemy.name}',
            style: const TextStyle(
              fontFamily: 'Cinzel',
              color: GraalTheme.amberLight,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: GraalTheme.danger, size: 16),
              const SizedBox(width: 6),
              Text(
                '${enemy.currentHp} / ${enemy.maxHp} PV',
                style: TextStyle(
                  fontFamily: 'Crimson Text',
                  color: hpColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (enemy.currentArmor > 0) ...[
                const SizedBox(width: 16),
                const Icon(Icons.shield, color: GraalTheme.textSecondary, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${enemy.currentArmor} armure',
                  style: const TextStyle(
                    fontFamily: 'Crimson Text',
                    color: GraalTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: GraalTheme.surfaceVariant,
              color: hpColor,
              minHeight: 6,
            ),
          ),
          if (enemy.specialNotes != null && enemy.specialNotes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '⚠️ ${enemy.specialNotes}',
                style: const TextStyle(
                  fontFamily: 'Crimson Text',
                  color: GraalTheme.amber,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerHpBar extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  const _PlayerHpBar({required this.currentHp, required this.maxHp});

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final color = ratio > 0.5
        ? GraalTheme.success
        : ratio > 0.25
            ? GraalTheme.amber
            : GraalTheme.dangerLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Text('PIP ', style: TextStyle(
            fontFamily: 'Cinzel', color: GraalTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: GraalTheme.surfaceVariant,
                color: color,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$currentHp / $maxHp',
            style: TextStyle(
              fontFamily: 'Crimson Text',
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CombatLog extends StatefulWidget {
  final List<String> log;
  const _CombatLog({required this.log});

  @override
  State<_CombatLog> createState() => _CombatLogState();
}

class _CombatLogState extends State<_CombatLog> {
  final ScrollController _sc = ScrollController();

  @override
  void didUpdateWidget(_CombatLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) {
        _sc.animateTo(
          _sc.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GraalTheme.surface,
        border: Border.all(color: GraalTheme.divider),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        controller: _sc,
        itemCount: widget.log.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            widget.log[i],
            style: const TextStyle(
              fontFamily: 'Crimson Text',
              color: GraalTheme.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerActions extends StatelessWidget {
  final PlayerState player;
  final VoidCallback onAttack;
  final void Function(String itemId) onMagic;
  final VoidCallback onFriendlyReaction;
  final void Function(dynamic paragraph) onCorruption;

  const _PlayerActions({
    required this.player,
    required this.onAttack,
    required this.onMagic,
    required this.onFriendlyReaction,
    required this.onCorruption,
  });

  @override
  Widget build(BuildContext context) {
    final magicRight = player.inventory.firstWhere(
      (i) => i.id == 'fire_finger_right', orElse: () =>
        InventoryItem(id: '_none', name: '', type: ItemType.magic, description: ''),
    );
    final magicLeft = player.inventory.firstWhere(
      (i) => i.id == 'fire_finger_left', orElse: () =>
        InventoryItem(id: '_none', name: '', type: ItemType.magic, description: ''),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          // Attaque principale
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAttack,
              icon: const Icon(Icons.gavel, size: 20),
              label: Text(
                '⚔️  Attaquer avec ${player.equippedWeapon?.name ?? "les poings"}',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF1A0E00),
                foregroundColor: GraalTheme.amber,
                side: const BorderSide(color: GraalTheme.amber),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Actions magiques et spéciales
          Row(
            children: [
              if (magicRight.id != '_none' && magicRight.usesRemaining > 0)
                Expanded(
                  child: _ActionButton(
                    label: '✨ Doigt de Feu D (${magicRight.usesRemaining})',
                    onTap: () => onMagic('fire_finger_right'),
                    color: GraalTheme.magic,
                  ),
                ),
              if (magicLeft.id != '_none' && magicLeft.usesRemaining > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: '✨ Doigt de Feu G (${magicLeft.usesRemaining})',
                    onTap: () => onMagic('fire_finger_left'),
                    color: GraalTheme.magic,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: '🤝 Réaction Amicale',
                  onTap: onFriendlyReaction,
                  color: GraalTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionButton({required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _VictoryDialog extends StatelessWidget {
  final String enemyName;
  final VoidCallback onContinue;
  const _VictoryDialog({required this.enemyName, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GraalTheme.surfaceVariant,
      title: const Text('🏆 Victoire !',
          style: TextStyle(fontFamily: 'Cinzel', color: GraalTheme.amberLight, fontSize: 22)),
      content: Text(
        'Vous avez vaincu $enemyName !\n\n+1 Point d\'Expérience gagné.',
        style: const TextStyle(fontFamily: 'Crimson Text', color: GraalTheme.textPrimary, fontSize: 17),
      ),
      actions: [
        ElevatedButton(onPressed: onContinue, child: const Text('Continuer')),
      ],
    );
  }
}

class _DeathDialog extends StatelessWidget {
  final VoidCallback onContinue;
  const _DeathDialog({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A0000),
      title: const Text('☠️  Vous êtes mort.',
          style: TextStyle(fontFamily: 'Cinzel', color: GraalTheme.dangerLight, fontSize: 22)),
      content: const Text(
        'L\'aventure s\'arrête ici... pour cette fois.\n\nVos ennemis vaincus restent morts lors de votre prochaine tentative.',
        style: TextStyle(fontFamily: 'Crimson Text', color: GraalTheme.textPrimary, fontSize: 17),
      ),
      actions: [
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: GraalTheme.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Recommencer'),
        ),
      ],
    );
  }
}
