// ============================================================
//  providers/persistence_service.dart — Sauvegarde automatique
// ============================================================
// Utilise shared_preferences pour sauvegarder l'état complet
// du joueur entre les sessions.
// ============================================================

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';

const _kSaveKey = 'graal_player_state';

// ── Provider SharedPreferences ────────────────────────────

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

// ── Service de sauvegarde ─────────────────────────────────

class PersistenceService {
  final SharedPreferences _prefs;
  PersistenceService(this._prefs);

  // ── Sauvegarder ───────────────────────────────────────────

  Future<void> saveState(PlayerState state) async {
    final map = _playerStateToMap(state);
    await _prefs.setString(_kSaveKey, jsonEncode(map));
  }

  // ── Charger ───────────────────────────────────────────────

  PlayerState? loadState() {
    final raw = _prefs.getString(_kSaveKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _playerStateFromMap(map);
    } catch (e) {
      // Sauvegarde corrompue → ignorer
      return null;
    }
  }

  // ── Effacer ───────────────────────────────────────────────

  Future<void> clearState() async {
    await _prefs.remove(_kSaveKey);
  }

  bool get hasSave => _prefs.containsKey(_kSaveKey);

  // ══════════════════════════════════════════════════════════
  //  Sérialisation
  // ══════════════════════════════════════════════════════════

  static Map<String, dynamic> _playerStateToMap(PlayerState s) => {
    'maxHp': s.maxHp,
    'currentHp': s.currentHp,
    'permanentHp': s.permanentHp,
    'xp': s.experiencePoints,
    'paragraph': s.currentParagraphId,
    'gold': s.purse.goldPieces,
    'silver': s.purse.silverPieces,
    'gems': s.purse.gems,
    'defeated': s.defeatedEnemies.toList(),
    'collectedLoot': s.collectedLoot.toList(),
    'history': s.history,
    'inventory': s.inventory.map(_itemToMap).toList(),
  };

  static PlayerState _playerStateFromMap(Map<String, dynamic> m) => PlayerState(
    maxHp: m['maxHp'] as int,
    currentHp: m['currentHp'] as int,
    permanentHp: m['permanentHp'] as int? ?? 0,
    experiencePoints: m['xp'] as int? ?? 0,
    currentParagraphId: m['paragraph'] as String,
    purse: Purse(
      goldPieces: m['gold'] as int? ?? 0,
      silverPieces: m['silver'] as int? ?? 0,
      gems: m['gems'] as int? ?? 0,
    ),
    defeatedEnemies: Set<String>.from(m['defeated'] as List? ?? []),
    collectedLoot: Set<String>.from(m['collectedLoot'] as List? ?? []),
    history: List<String>.from(m['history'] as List? ?? []),
    inventory: (m['inventory'] as List? ?? [])
        .map((i) => _itemFromMap(i as Map<String, dynamic>))
        .toList(),
  );

  static Map<String, dynamic> _itemToMap(InventoryItem i) => {
    'id': i.id,
    'name': i.name,
    'type': i.type.name,
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
      (e) => e.name == m['type'], orElse: () => ItemType.quest,
    ),
    description: m['description'] as String? ?? '',
    attackThresholdOverride: m['attackThresholdOverride'] as int?,
    bonusDamage: m['bonusDamage'] as int? ?? 0,
    damageReduction: m['damageReduction'] as int? ?? 0,
    usesRemaining: m['usesRemaining'] as int? ?? 0,
    usesTotal: m['usesTotal'] as int? ?? 0,
    effect: m['effect'] as String?,
  );
}

// ── Provider du service ───────────────────────────────────

final persistenceServiceProvider = Provider<PersistenceService?>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return prefsAsync.whenOrNull(data: (prefs) => PersistenceService(prefs));
});
