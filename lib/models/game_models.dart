// ============================================================
//  models/game_models.dart  —  Modèles de données typés
// ============================================================

import 'dart:convert';

// ─── Objet d'inventaire ────────────────────────────────────

enum ItemType { weapon, armor, consumable, magic, quest, gold }

class InventoryItem {
  final String id;
  final String name;
  final ItemType type;
  final String description;
  final String? imageAsset;

  // Weapon
  final int? attackThresholdOverride; // null = 6 (standard), 4 pour E.J.
  final int bonusDamage;

  // Armor
  final int damageReduction; // ex: 5 pour pourpoint en peau de dragon

  // Consumable / Magic
  int usesRemaining;
  final int usesTotal;
  final String? effect; // "heal_2d6", "damage_10_no_roll", etc.

  // Dragon coat special rule
  final bool bypassedByWolf; // Le loup contourne le pourpoint

  InventoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    this.imageAsset,
    this.attackThresholdOverride,
    this.bonusDamage = 0,
    this.damageReduction = 0,
    this.usesRemaining = 0,
    this.usesTotal = 0,
    this.effect,
    this.bypassedByWolf = false,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      name: json['name'],
      type: ItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ItemType.quest,
      ),
      description: json['description'] ?? '',
      attackThresholdOverride: json['attack_threshold_override'],
      bonusDamage: json['bonus_damage'] ?? 0,
      damageReduction: json['damage_reduction'] ?? 0,
      usesRemaining: json['uses_remaining'] ?? 0,
      usesTotal: json['uses_total'] ?? 0,
      effect: json['effect'],
    );
  }

  InventoryItem copyWith({int? usesRemaining}) {
    return InventoryItem(
      id: id, name: name, type: type, description: description,
      attackThresholdOverride: attackThresholdOverride,
      bonusDamage: bonusDamage, damageReduction: damageReduction,
      usesRemaining: usesRemaining ?? this.usesRemaining,
      usesTotal: usesTotal, effect: effect,
    );
  }
}

// ─── Ennemi ────────────────────────────────────────────────

class Enemy {
  final String id;
  final String name;
  final int maxHp;
  final int attackThreshold;  // Score minimal pour toucher le joueur (défaut 6)
  final int bonusDamage;
  final int armorPoints;
  final bool playerCoatBypassed; // Contourne le pourpoint en peau de dragon
  final bool strikesFirst;
  final String? imageAsset;
  final String? specialNotes;

  // État de combat (mutable)
  int currentHp;
  int currentArmor;

  Enemy({
    required this.id,
    required this.name,
    required this.maxHp,
    this.attackThreshold = 6,
    this.bonusDamage = 0,
    this.armorPoints = 0,
    this.playerCoatBypassed = false,
    this.strikesFirst = false,
    this.imageAsset,
    this.specialNotes,
  })  : currentHp = maxHp,
        currentArmor = armorPoints;

  factory Enemy.fromJson(Map<String, dynamic> json) {
    return Enemy(
      id: json['id'],
      name: json['name'],
      maxHp: json['max_hp'],
      attackThreshold: json['attack_threshold'] ?? 6,
      bonusDamage: json['bonus_damage'] ?? 0,
      armorPoints: json['armor_points'] ?? 0,
      playerCoatBypassed: json['dragon_coat_bypassed'] ?? false,
      strikesFirst: json['strikes_first'] ?? false,
      imageAsset: json['image'],
    );
  }

  bool get isKnockedOut => currentHp <= 5;
  bool get isDead => currentHp <= 0;

  Enemy clone() => Enemy(
    id: id, name: name, maxHp: maxHp, attackThreshold: attackThreshold,
    bonusDamage: bonusDamage, armorPoints: armorPoints,
    playerCoatBypassed: playerCoatBypassed, strikesFirst: strikesFirst,
    imageAsset: imageAsset, specialNotes: specialNotes,
  )..currentHp = currentHp..currentArmor = currentArmor;
}

// ─── Choix de navigation ────────────────────────────────────

class ParagraphChoice {
  final String text;
  final String targetParagraph;
  final String? requiresItem;   // ID d'objet requis (null = pas de prérequis)
  final int? requiresGold;      // Or minimum requis
  final bool hiddenIfMissing;   // true = bouton invisible si condition non remplie
  final bool triggersCorruption;
  final bool resetsGame;

  const ParagraphChoice({
    required this.text,
    required this.targetParagraph,
    this.requiresItem,
    this.requiresGold,
    this.hiddenIfMissing = false,
    this.triggersCorruption = false,
    this.resetsGame = false,
  });

  factory ParagraphChoice.fromJson(Map<String, dynamic> json) {
    return ParagraphChoice(
      text: json['text'],
      targetParagraph: json['target_paragraph'],
      requiresItem: json['requires_item'],
      requiresGold: json['requires_gold'],
      hiddenIfMissing: json['hidden_if_missing'] ?? false,
      triggersCorruption: json['triggers_corruption'] ?? false,
      resetsGame: json['resets_game'] ?? false,
    );
  }
}

// ─── Données de combat intégrées au paragraphe ─────────────

class CombatData {
  final String enemyId;
  final bool? playerStrikesFirst;   // null = tirage au sort (§8 du Rêve)
  final String onWinParagraph;
  final String onDeathParagraph;
  final int multiCount;             // 1 = normal, 2+ = multi-combat
  final String? special;            // "zombie_kill_only_on_9_12", etc.

  const CombatData({
    required this.enemyId,
    this.playerStrikesFirst,
    required this.onWinParagraph,
    required this.onDeathParagraph,
    this.multiCount = 1,
    this.special,
  });

  factory CombatData.fromJson(Map<String, dynamic> json) {
    return CombatData(
      enemyId: json['enemy_id'] as String,
      playerStrikesFirst: json['player_strikes_first'] as bool?,
      onWinParagraph: json['on_win_paragraph'] as String,
      onDeathParagraph: json['on_death_paragraph'] as String,
      multiCount: json['multi_count'] as int? ?? 1,
      special: json['special'] as String?,
    );
  }
}

// ─── Paragraphe ────────────────────────────────────────────

class Paragraph {
  final String id;
  final String title;
  final String text; // Markdown
  final String? imageAsset;
  final CombatData? combat;
  final List<ParagraphChoice> choices;
  final List<Map<String, dynamic>> loot;  // [{type:"gold", amount:100}, {type:"item", item_id:"ej"}]
  final int? corruptionTier;   // null, 1, 2, 3 ou 4
  final bool isDeathParagraph;
  final int grantsXp;

  const Paragraph({
    required this.id,
    required this.title,
    required this.text,
    this.imageAsset,
    this.combat,
    this.choices = const [],
    this.loot = const [],
    this.corruptionTier,
    this.isDeathParagraph = false,
    this.grantsXp = 0,
  });

  factory Paragraph.fromJson(Map<String, dynamic> json) {
    return Paragraph(
      id: json['id'],
      title: json['title'] ?? '',
      text: json['text'] ?? '',
      imageAsset: json['image'],
      combat: json['combat'] != null
          ? CombatData.fromJson(json['combat'])
          : null,
      choices: (json['choices'] as List<dynamic>? ?? [])
          .map((c) => ParagraphChoice.fromJson(c))
          .toList(),
      loot: List<Map<String, dynamic>>.from(json['loot'] ?? []),
      corruptionTier: json['corruption_tier'],
      isDeathParagraph: json['is_death_paragraph'] ?? false,
      grantsXp: json['grants_xp'] ?? 0,
    );
  }
}

// ─── Bourse ────────────────────────────────────────────────

class Purse {
  final int goldPieces;
  final int silverPieces;
  final int gems;

  const Purse({
    this.goldPieces = 0,
    this.silverPieces = 0,
    this.gems = 0,
  });

  Purse copyWith({int? goldPieces, int? silverPieces, int? gems}) {
    return Purse(
      goldPieces: goldPieces ?? this.goldPieces,
      silverPieces: silverPieces ?? this.silverPieces,
      gems: gems ?? this.gems,
    );
  }

  factory Purse.fromJson(Map<String, dynamic> json) {
    return Purse(
      goldPieces: json['gold_pieces'] ?? 0,
      silverPieces: json['silver_pieces'] ?? 0,
      gems: json['gems'] ?? 0,
    );
  }
}

// ─── État global du joueur ─────────────────────────────────

class PlayerState {
  final int maxHp;
  final int currentHp;
  final int permanentHp;         // Points permanents cumulés
  final int experiencePoints;
  final List<InventoryItem> inventory;
  final Purse purse;
  final String currentParagraphId;
  final Set<String> defeatedEnemies;  // IDs des ennemis tués (persistent)
  final Set<String> collectedLoot;    // IDs de loot déjà ramassé
  final List<String> history;         // Historique des IDs parcourus

  const PlayerState({
    required this.maxHp,
    required this.currentHp,
    this.permanentHp = 0,
    this.experiencePoints = 0,
    this.inventory = const [],
    this.purse = const Purse(),
    this.currentParagraphId = 'intro',
    this.defeatedEnemies = const {},
    this.collectedLoot = const {},
    this.history = const [],
  });

  // ── Getters utiles ─────────────────────────────────────────

  bool get isDead => currentHp <= 0;
  bool get isKnockedOut => currentHp <= 5 && currentHp > 0;

  InventoryItem? get equippedWeapon => inventory.firstWhere(
    (i) => i.type == ItemType.weapon && i.id == 'ej',
    orElse: () => inventory.firstWhere(
      (i) => i.type == ItemType.weapon,
      orElse: () => InventoryItem(
        id: 'fists', name: 'Poings', type: ItemType.weapon, description: '',
      ),
    ),
  );

  InventoryItem? get equippedArmor => inventory.firstWhere(
    (i) => i.type == ItemType.armor,
    orElse: () => InventoryItem(
      id: 'none', name: 'Aucune armure', type: ItemType.armor, description: '',
    ),
  );

  bool hasItem(String itemId) => inventory.any((i) => i.id == itemId);
  bool hasGold(int amount) => purse.goldPieces >= amount;

  int get attackThreshold {
    final weapon = equippedWeapon;
    return weapon?.attackThresholdOverride ?? 6;
  }

  int get weaponBonusDamage {
    return equippedWeapon?.bonusDamage ?? 0;
  }

  int get armorReduction {
    return equippedArmor?.damageReduction ?? 0;
  }

  // ── Calculs XP ────────────────────────────────────────────

  int get xpToNextPermanentHp => 20 - (experiencePoints % 20);
  int get totalPermanentHpEarned => experiencePoints ~/ 20;

  // ── copyWith ───────────────────────────────────────────────

  PlayerState copyWith({
    int? maxHp,
    int? currentHp,
    int? permanentHp,
    int? experiencePoints,
    List<InventoryItem>? inventory,
    Purse? purse,
    String? currentParagraphId,
    Set<String>? defeatedEnemies,
    Set<String>? collectedLoot,
    List<String>? history,
  }) {
    return PlayerState(
      maxHp: maxHp ?? this.maxHp,
      currentHp: (currentHp ?? this.currentHp).clamp(0, (maxHp ?? this.maxHp) + (permanentHp ?? this.permanentHp)),
      permanentHp: permanentHp ?? this.permanentHp,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      inventory: inventory ?? this.inventory,
      purse: purse ?? this.purse,
      currentParagraphId: currentParagraphId ?? this.currentParagraphId,
      defeatedEnemies: defeatedEnemies ?? this.defeatedEnemies,
      collectedLoot: collectedLoot ?? this.collectedLoot,
      history: history ?? this.history,
    );
  }
}
