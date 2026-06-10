// ============================================================
//  widgets/loot_dialog.dart — Affichage du butin
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';

class LootDialog extends ConsumerWidget {
  final String paragraphId;
  final List<Map<String, dynamic>> loot;
  final VoidCallback onClose;

  const LootDialog({
    super.key,
    required this.paragraphId,
    required this.loot,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      backgroundColor: GraalTheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: GraalTheme.amber, width: 1),
      ),
      title: const Row(children: [
        Text('🎁 ', style: TextStyle(fontSize: 22)),
        Text('Objet trouvé !', style: TextStyle(
          fontFamily: 'Cinzel', color: GraalTheme.amberLight, fontSize: 20)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: loot.map((l) => _LootEntry(loot: l)).toList(),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            _applyLoot(ref, loot, paragraphId);
            onClose();
          },
          child: const Text('Ramasser'),
        ),
        TextButton(
          onPressed: onClose,
          child: const Text('Ignorer', style: TextStyle(color: GraalTheme.textSecondary)),
        ),
      ],
    );
  }

  static void _applyLoot(WidgetRef ref, List<Map<String, dynamic>> loot, String pid) {
    final notifier = ref.read(playerStateProvider.notifier);

    for (final l in loot) {
      switch (l['type'] as String?) {
        case 'gold':
          notifier.addGold((l['amount'] as num?)?.toInt() ?? 0);
          break;
        case 'item':
          final item = InventoryItem(
            id: l['item_id'] as String? ?? 'unknown_$pid',
            name: l['name'] as String? ?? 'Objet inconnu',
            type: ItemType.values.firstWhere(
              (t) => t.name == (l['item_type'] as String? ?? 'quest'),
              orElse: () => ItemType.quest,
            ),
            description: l['description'] as String? ?? '',
            usesRemaining: l['uses_remaining'] as int? ?? 0,
            usesTotal: l['uses_total'] as int? ?? 0,
            effect: l['effect'] as String?,
          );
          notifier.addItem(item);
          break;
        case 'special':
          final effect = l['effect'] as String? ?? '';
          if (effect == 'heal_to_max_plus_25_temp') {
            // Calice de la Dame du Lac
            final player = ref.read(playerStateProvider);
            notifier.heal(player.maxHp + player.permanentHp);
            notifier.gainXp(0); // pas d'XP, mais noter l'effet
            // +25 PV temporaires → on les ajoute comme bonus permanent temporaire
            // Implémentation simplifiée : on augmente le maxHp de 25
            // (à retirer manuellement dans le scénario)
          }
          break;
      }
    }

    // Marquer ce loot comme collecté pour ne pas le représenter
    notifier.markLootCollected(pid);
  }
}

class _LootEntry extends StatelessWidget {
  final Map<String, dynamic> loot;
  const _LootEntry({required this.loot});

  @override
  Widget build(BuildContext context) {
    final type = loot['type'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(_icon(type), style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title(), style: const TextStyle(
              fontFamily: 'Crimson Text', color: GraalTheme.textPrimary,
              fontSize: 16, fontWeight: FontWeight.bold)),
            if (_subtitle().isNotEmpty)
              Text(_subtitle(), style: const TextStyle(
                fontFamily: 'Crimson Text', color: GraalTheme.textSecondary, fontSize: 14)),
          ],
        )),
      ]),
    );
  }

  String _icon(String type) {
    return switch (type) {
      'gold'    => '💰',
      'item'    => _itemIcon(),
      'special' => '✨',
      _         => '📦',
    };
  }

  String _itemIcon() {
    final itype = loot['item_type'] as String? ?? '';
    return switch (itype) {
      'weapon'     => '⚔️',
      'armor'      => '🛡️',
      'consumable' => '🧪',
      'magic'      => '✨',
      _            => '🔮',
    };
  }

  String _title() {
    final type = loot['type'] as String? ?? '';
    if (type == 'gold') {
      return '${loot['amount']} Pièces d\'Or';
    }
    return loot['name'] as String? ?? 'Objet';
  }

  String _subtitle() {
    return loot['description'] as String? ?? '';
  }
}
