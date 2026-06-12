// ============================================================
//  widgets/character_drawer.dart  —  Feuille de personnage
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';

class CharacterDrawer extends ConsumerWidget {
  const CharacterDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerStateProvider);

    return Drawer(
      backgroundColor: GraalTheme.surfaceVariant,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─ En-tête ──────────────────────────────────
              const Text(
                'FEUILLE DE PIP',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: GraalTheme.amber,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              const Divider(color: GraalTheme.divider),

              // ─ Points de Vie ─────────────────────────────
              _Section(
                title: '❤️  Points de Vie',
                child: Column(
                  children: [
                    _StatRow('PV actuels', '${player.currentHp}', GraalTheme.dangerLight),
                    _StatRow('PV maximums', '${player.maxHp}', GraalTheme.textSecondary),
                    _StatRow('PV permanents', '+${player.permanentHp}', GraalTheme.success),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: player.maxHp > 0
                            ? (player.currentHp / player.maxHp).clamp(0.0, 1.0)
                            : 0,
                        backgroundColor: GraalTheme.surface,
                        color: GraalTheme.dangerLight,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // ─ Expérience ────────────────────────────────
              _Section(
                title: '⭐  Expérience',
                child: Column(
                  children: [
                    _StatRow('Points XP', '${player.experiencePoints}', GraalTheme.amberLight),
                    _StatRow('Prochain PV permanent',
                        'dans ${20 - (player.experiencePoints % 20)} XP', GraalTheme.textSecondary),
                  ],
                ),
              ),

              // ─ Bourse ────────────────────────────────────
              _Section(
                title: '💰  Bourse',
                child: Column(
                  children: [
                    _StatRow('Pièces d\'or', '${player.purse.goldPieces} P.O.', GraalTheme.gold),
                    _StatRow('Pièces d\'argent', '${player.purse.silverPieces} P.A.', GraalTheme.textSecondary),
                    _StatRow('Gemmes', '${player.purse.gems}', GraalTheme.magic),
                  ],
                ),
              ),

              // ─ Armement ──────────────────────────────────
              _Section(
                title: '⚔️  Armement actif',
                child: Column(
                  children: [
                    _StatRow('Arme',
                      player.inventory.where((i) => i.type == ItemType.weapon).map((i) => i.name).firstOrNull ?? 'Aucune',
                      GraalTheme.amberLight),
                    if (player.attackThreshold < 6)
                      _StatRow('Seuil d\'attaque',
                          '${player.attackThreshold} (au lieu de 6)', GraalTheme.success),
                    if (player.weaponBonusDamage > 0)
                      _StatRow('Bonus dégâts arme',
                          '+${player.weaponBonusDamage}', GraalTheme.success),
                    _StatRow('Armure',
                      player.inventory.where((i) => i.type == ItemType.armor).map((i) => i.name).firstOrNull ?? 'Aucune',
                      GraalTheme.textSecondary),
                    if (player.armorReduction > 0)
                      _StatRow('Réduction dégâts',
                          '-${player.armorReduction}', GraalTheme.success),
                  ],
                ),
              ),

              // ─ Inventaire complet ─────────────────────────
              _Section(
                title: '🎒  Inventaire',
                child: Column(
                  children: player.inventory.isEmpty
                      ? [const Text('Rien.', style: TextStyle(color: GraalTheme.textDim))]
                      : player.inventory.map((item) => _InventoryTile(item: item)).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // ─ Règles résumées ────────────────────────────
              _RulesQuickRef(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sous-widgets ──────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              color: GraalTheme.amber,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ),
        child,
        const Divider(color: GraalTheme.divider),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(
            fontFamily: 'Crimson Text', color: GraalTheme.textSecondary, fontSize: 15)),
          Text(value, style: TextStyle(
            fontFamily: 'Crimson Text', color: valueColor, fontSize: 15,
            fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final InventoryItem item;
  const _InventoryTile({required this.item});

  IconData get _icon {
    return switch (item.type) {
      ItemType.weapon => Icons.gavel,
      ItemType.armor => Icons.shield,
      ItemType.consumable => Icons.local_pharmacy,
      ItemType.magic => Icons.auto_fix_high,
      ItemType.quest => Icons.star,
      ItemType.gold => Icons.monetization_on,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_icon, color: GraalTheme.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(
                  fontFamily: 'Crimson Text', color: GraalTheme.textPrimary, fontSize: 15)),
                if (item.usesTotal > 0)
                  Text('Utilisations : ${item.usesRemaining}/${item.usesTotal}',
                      style: const TextStyle(color: GraalTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesQuickRef extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GraalTheme.surface,
        border: Border.all(color: GraalTheme.divider),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RÈGLES RAPIDES', style: TextStyle(
            fontFamily: 'Cinzel', color: GraalTheme.amber,
            fontSize: 11, letterSpacing: 1.5)),
          SizedBox(height: 8),
          _RuleLine('⚔️ Toucher', 'Lancer 2d6 > seuil (6 std, 4 avec E.J.)'),
          _RuleLine('💀 Dommages', 'Points au-dessus du seuil + bonus arme'),
          _RuleLine('😵 KO ennemi', 'Quand ses PV ≤ 5'),
          _RuleLine('☠️ Mort ennemi', 'Quand ses PV ≤ 0'),
          _RuleLine('💤 Sommeil', '1d6 : 1-4 = Rêve | 5-6 = +2d6 PV'),
          _RuleLine('⭐ XP', '1 par combat/énigme | 20 XP = +1 PV perm.'),
          _RuleLine('💰 Corruption', '*C = 100 P.O., **C = 500, ***C = 1000'),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final String label;
  final String value;
  const _RuleLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            fontFamily: 'Crimson Text', color: GraalTheme.amberLight,
            fontSize: 13, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(
            fontFamily: 'Crimson Text', color: GraalTheme.textSecondary,
            fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }
}
