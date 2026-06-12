import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';

const _kSaveKey = 'graal_player_state_v3';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

class PersistenceService {
  final SharedPreferences _prefs;
  PersistenceService(this._prefs);

  Future<void> saveState(PlayerState s) async {
    final map = {
      'maxHp': s.maxHp,
      'currentHp': s.currentHp,
      'permanentHp': s.permanentHp,
      'xp': s.experiencePoints,
      'chapterId': s.currentChapterId,
      'paragraphId': s.currentParagraphId,
      'gold': s.purse.goldPieces,
      'silver': s.purse.silverPieces,
      'gems': s.purse.gems,
      'defeated': s.defeatedEnemies.toList(),
      'collectedLoot': s.collectedLoot.toList(),
      'inventory': s.inventory.map(_itemToMap).toList(),
    };
    await _prefs.setString(_kSaveKey, jsonEncode(map));
  }

  PlayerState? loadState() {
    final raw = _prefs.getString(_kSaveKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return PlayerState(
        maxHp: m['maxHp'] as int,
        currentHp: m['currentHp'] as int,
        permanentHp: m['permanentHp'] as int? ?? 0,
        experiencePoints: m['xp'] as int? ?? 0,
        currentChapterId: m['chapterId'] as String? ?? 'ch_merlin',
        currentParagraphId: m['paragraphId'] as String?,
        purse: Purse(
          goldPieces: m['gold'] as int? ?? 0,
          silverPieces: m['silver'] as int? ?? 0,
          gems: m['gems'] as int? ?? 0,
        ),
        defeatedEnemies: Set<String>.from(m['defeated'] as List? ?? []),
        collectedLoot: Set<String>.from(m['collectedLoot'] as List? ?? []),
        inventory: (m['inventory'] as List? ?? [])
            .map((i) => _itemFromMap(i as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  bool get hasSave => _prefs.containsKey(_kSaveKey);
  Future<void> clearState() async => _prefs.remove(_kSaveKey);

  static Map<String, dynamic> _itemToMap(InventoryItem i) => {
    'id': i.id, 'name': i.name, 'type': i.type.name,
    'description': i.description,
    'attackThresholdOverride': i.attackThresholdOverride,
    'bonusDamage': i.bonusDamage,
    'damageReduction': i.damageReduction,
    'usesRemaining': i.usesRemaining,
    'usesTotal': i.usesTotal,
    'effect': i.effect,
  };

  static InventoryItem _itemFromMap(Map<String, dynamic> m) => InventoryItem(
    id: m['id'] as String,
    name: m['name'] as String,
    type: ItemType.values.firstWhere(
      (e) => e.name == m['type'], orElse: () => ItemType.quest),
    description: m['description'] as String? ?? '',
    attackThresholdOverride: m['attackThresholdOverride'] as int?,
    bonusDamage: m['bonusDamage'] as int? ?? 0,
    damageReduction: m['damageReduction'] as int? ?? 0,
    usesRemaining: m['usesRemaining'] as int? ?? 0,
    usesTotal: m['usesTotal'] as int? ?? 0,
    effect: m['effect'] as String?,
  );
}

final persistenceServiceProvider = Provider<PersistenceService?>((ref) {
  return ref.watch(sharedPreferencesProvider).whenOrNull(
    data: (prefs) => PersistenceService(prefs),
  );
});
