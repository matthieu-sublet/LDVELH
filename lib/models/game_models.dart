import 'dart:convert';

// ── Types ──────────────────────────────────────────────────

enum ChapterType { narration, jeu }
enum ItemType { weapon, armor, consumable, magic, quest, gold }

// ── Chapitre narratif ou de jeu ───────────────────────────

class GameChapter {
  final int order;
  final String id;
  final String title;
  final ChapterType type;
  // Narration
  final String? contenu;
  final String? suivant;
  // Jeu
  final String? paragrapheDepart;
  final List<GameParagraph> paragraphes;

  const GameChapter({
    required this.order,
    required this.id,
    required this.title,
    required this.type,
    this.contenu,
    this.suivant,
    this.paragrapheDepart,
    this.paragraphes = const [],
  });

  factory GameChapter.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'narration';
    return GameChapter(
      order: json['order'] as int? ?? 0,
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      type: typeStr == 'jeu' ? ChapterType.jeu : ChapterType.narration,
      contenu: json['contenu'] as String?,
      suivant: json['suivant'] as String?,
      paragrapheDepart: json['paragrapheDepart'] as String?,
      paragraphes: (json['paragraphes'] as List<dynamic>? ?? [])
          .map((p) => GameParagraph.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Paragraphe de jeu ─────────────────────────────────────

class GameParagraph {
  final String id;
  final String title;
  final String text;
  final int? corruptionTier;
  final EnemyData? enemy;
  final List<ParagraphChoice> choices;
  final bool canDie;

  const GameParagraph({
    required this.id,
    required this.title,
    required this.text,
    this.corruptionTier,
    this.enemy,
    this.choices = const [],
    this.canDie = false,
  });

  factory GameParagraph.fromJson(Map<String, dynamic> json) {
    return GameParagraph(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      corruptionTier: json['corruptionTier'] as int?,
      enemy: json['enemy'] != null
          ? EnemyData.fromJson(json['enemy'] as Map<String, dynamic>)
          : null,
      choices: (json['choices'] as List<dynamic>? ?? [])
          .map((c) => ParagraphChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
      canDie: json['canDie'] as bool? ?? false,
    );
  }
}

// ── Ennemi ────────────────────────────────────────────────

class EnemyData {
  final String name;
  final int lifePoints;
  final int extraDamage;
  int currentHp;

  EnemyData({
    required this.name,
    required this.lifePoints,
    this.extraDamage = 0,
  }) : currentHp = lifePoints;

  factory EnemyData.fromJson(Map<String, dynamic> json) {
    return EnemyData(
      name: json['name'] as String? ?? 'Ennemi',
      lifePoints: json['lifePoints'] as int? ?? 10,
      extraDamage: json['extraDamage'] as int? ?? 0,
    );
  }

  EnemyData clone() => EnemyData(
    name: name, lifePoints: lifePoints, extraDamage: extraDamage,
  )..currentHp = currentHp;

  bool get isDead => currentHp <= 0;
  bool get isKnockedOut => currentHp <= 5 && currentHp > 0;
}

// ── Choix de navigation ───────────────────────────────────

class ParagraphChoice {
  final String text;
  final String nextId;
  final String? requiresItem;
  final int? requiresGold;
  final bool hiddenIfMissing;
  final bool resetsGame;

  const ParagraphChoice({
    required this.text,
    required this.nextId,
    this.requiresItem,
    this.requiresGold,
    this.hiddenIfMissing = false,
    this.resetsGame = false,
  });

  factory ParagraphChoice.fromJson(Map<String, dynamic> json) {
    return ParagraphChoice(
      text: json['text'] as String? ?? '',
      nextId: json['nextId'] as String? ?? json['target_paragraph'] as String? ?? '',
      requiresItem: json['requiresItem'] as String?,
      requiresGold: json['requiresGold'] as int?,
      hiddenIfMissing: json['hiddenIfMissing'] as bool? ?? false,
      resetsGame: json['resetsGame'] as bool? ?? false,
    );
  }
}

// ── Données du livre complet ──────────────────────────────

class GameBook {
  final List<GameChapter> histoire;
  final Map<String, String> annexes;
  final DreamTime tempsDuReve;

  const GameBook({
    required this.histoire,
    required this.annexes,
    required this.tempsDuReve,
  });

  factory GameBook.fromJson(Map<String, dynamic> json) {
    return GameBook(
      histoire: (json['histoire'] as List<dynamic>? ?? [])
          .map((c) => GameChapter.fromJson(c as Map<String, dynamic>))
          .toList(),
      annexes: Map<String, String>.from(
        (json['annexes'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      ),
      tempsDuReve: DreamTime.fromJson(
        json['tempsDuReve'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  GameChapter? chapterById(String id) {
    try {
      return histoire.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  GameParagraph? paragraphById(String paraId) {
    for (final ch in histoire) {
      for (final p in ch.paragraphes) {
        if (p.id == paraId) return p;
      }
    }
    return null;
  }
}

// ── Temps du Rêve ─────────────────────────────────────────

class DreamSection {
  final String id;
  final String text;
  final List<ParagraphChoice> choices;

  const DreamSection({
    required this.id,
    required this.text,
    this.choices = const [],
  });

  factory DreamSection.fromJson(Map<String, dynamic> json) {
    return DreamSection(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      choices: (json['choices'] as List<dynamic>? ?? [])
          .map((c) => ParagraphChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DreamTime {
  final String description;
  final List<DreamSection> sections;

  const DreamTime({required this.description, required this.sections});

  factory DreamTime.fromJson(Map<String, dynamic> json) {
    return DreamTime(
      description: json['description'] as String? ?? '',
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((s) => DreamSection.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Objets d'inventaire ───────────────────────────────────

class InventoryItem {
  final String id;
  final String name;
  final ItemType type;
  final String description;
  final int? attackThresholdOverride;
  final int bonusDamage;
  final int damageReduction;
  int usesRemaining;
  final int usesTotal;
  final String? effect;

  InventoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    this.attackThresholdOverride,
    this.bonusDamage = 0,
    this.damageReduction = 0,
    this.usesRemaining = 0,
    this.usesTotal = 0,
    this.effect,
  });

  InventoryItem copyWith({int? usesRemaining}) => InventoryItem(
    id: id, name: name, type: type, description: description,
    attackThresholdOverride: attackThresholdOverride,
    bonusDamage: bonusDamage, damageReduction: damageReduction,
    usesRemaining: usesRemaining ?? this.usesRemaining,
    usesTotal: usesTotal, effect: effect,
  );
}

// ── Bourse ────────────────────────────────────────────────

class Purse {
  final int goldPieces;
  final int silverPieces;
  final int gems;

  const Purse({
    this.goldPieces = 0,
    this.silverPieces = 0,
    this.gems = 0,
  });

  Purse copyWith({int? goldPieces, int? silverPieces, int? gems}) => Purse(
    goldPieces: goldPieces ?? this.goldPieces,
    silverPieces: silverPieces ?? this.silverPieces,
    gems: gems ?? this.gems,
  );
}

// ── État du joueur ────────────────────────────────────────

class PlayerState {
  final int maxHp;
  final int currentHp;
  final int permanentHp;
  final int experiencePoints;
  final List<InventoryItem> inventory;
  final Purse purse;
  // Navigation
  final String currentChapterId;    // ex: "ch_mission"
  final String? currentParagraphId; // ex: "3" (null si narration)
  final Set<String> defeatedEnemies;
  final Set<String> collectedLoot;

  const PlayerState({
    required this.maxHp,
    required this.currentHp,
    this.permanentHp = 0,
    this.experiencePoints = 0,
    this.inventory = const [],
    this.purse = const Purse(),
    this.currentChapterId = 'ch_merlin',
    this.currentParagraphId,
    this.defeatedEnemies = const {},
    this.collectedLoot = const {},
  });

  bool get isDead => currentHp <= 0;
  bool hasItem(String id) => inventory.any((i) => i.id == id);
  bool hasGold(int amount) => purse.goldPieces >= amount;

  int get attackThreshold {
    final w = inventory.firstWhere(
      (i) => i.type == ItemType.weapon && i.attackThresholdOverride != null,
      orElse: () => InventoryItem(id:'_', name:'', type:ItemType.weapon, description:''),
    );
    return w.attackThresholdOverride ?? 6;
  }

  int get weaponBonusDamage {
    int bonus = 0;
    for (final i in inventory) {
      if (i.type == ItemType.weapon) bonus += i.bonusDamage;
    }
    return bonus;
  }

  int get armorReduction {
    int r = 0;
    for (final i in inventory) {
      if (i.type == ItemType.armor) r += i.damageReduction;
    }
    return r;
  }

  PlayerState copyWith({
    int? maxHp, int? currentHp, int? permanentHp, int? experiencePoints,
    List<InventoryItem>? inventory, Purse? purse,
    String? currentChapterId, String? currentParagraphId,
    Set<String>? defeatedEnemies, Set<String>? collectedLoot,
    bool clearParagraph = false,
  }) {
    return PlayerState(
      maxHp: maxHp ?? this.maxHp,
      currentHp: (currentHp ?? this.currentHp).clamp(0, (maxHp ?? this.maxHp) + (permanentHp ?? this.permanentHp)),
      permanentHp: permanentHp ?? this.permanentHp,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      inventory: inventory ?? this.inventory,
      purse: purse ?? this.purse,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      currentParagraphId: clearParagraph ? null : (currentParagraphId ?? this.currentParagraphId),
      defeatedEnemies: defeatedEnemies ?? this.defeatedEnemies,
      collectedLoot: collectedLoot ?? this.collectedLoot,
    );
  }
}
