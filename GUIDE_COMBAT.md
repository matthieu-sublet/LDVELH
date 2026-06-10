# Guide d'implémentation — Moteur de Combat
## La Quête du Graal : Le Château des Ténèbres

---

## 1. Règles du livre, formalisées

### 1.1 Attaque de base
```
TOUCHÉ si : lancer_2d6 > seuil_attaque

seuil_attaque = 6 (standard)
              = 4 (avec Excalibur Junior)
              = 5 (certains ennemis, ex: Monstre Végétal)

Points de Dommage infligés = (résultat_dé - seuil) + bonus_arme
```

### 1.2 Table des armes
| Arme | Seuil joueur | Bonus dégâts | Note |
|------|-------------|-------------|------|
| Poings nus | 6 | 0 | Pas d'arme équipée |
| Dague | 6 | +2 | — |
| Excalibur Junior (E.J.) | **4** | **+5** | Parle parfois |
| Doigt de Feu | — | **10 fixes** | Ne rate jamais, 5 charges/doigt |
| Boule de Feu | — | **75** | Lance 2d6, touche si > 5, 2 charges |

### 1.3 Armures
| Armure | Réduction | Règle spéciale |
|--------|-----------|----------------|
| Pourpoint en peau de dragon | -5 dégâts reçus | Contourné par le Loup (attaque parties non couvertes) |
| Armure d'ennemi (ex: Ansalom) | Absorbe d'abord | Une fois détruite → dégâts directs aux PV |

### 1.4 État KO vs Mort
```
PV ennemi ≤ 5  → KO (assommé) : traité comme victoire
PV ennemi = 0  → Mort

PV joueur ≤ 5  → KO → § 14 (mort narrative)
PV joueur = 0  → Mort → § 14
```

---

## 2. Séquence de combat — Flowchart

```
[ENTRÉE dans paragraphe de combat]
         │
         ▼
┌─────────────────────────────┐
│  Vérifier qui frappe d'abord│
│  (playerStrikesFirst JSON)  │
└──────────┬──────────────────┘
           │
    ┌──────┴──────┐
    │             │
 JOUEUR       ENNEMI
 EN PREMIER   EN PREMIER
    │             │
    ▼             ▼
[PHASE JOUEUR]     [PHASE ENNEMI]
Choisir action :   Auto-résolu :
• Attaquer (2d6)   lancer_2d6 pour l'ennemi
• Doigt de Feu     si > seuil ennemi → dégâts joueur
• Réaction Amicale (3 lancers joueur < 1 lancer ennemi)
• Corruption (si paragraphe *C)
    │
    ▼
[Calculer dégâts]
  si touché :
    dégâts = (dé - seuil) + bonus_arme
    si armure ennemi > 0 :
      absorption = min(dégâts, armure_restante)
      armure_restante -= absorption
      dégâts -= absorption
    PV_ennemi -= dégâts
    │
    ▼
[Vérifier état ennemi]
 PV ≤ 5 ou PV ≤ 0 → VICTOIRE
 sinon → PHASE ENNEMI
    │
    ▼
[PHASE ENNEMI — auto-résolu]
  lancer_2d6 pour l'ennemi
  si > seuil_ennemi :
    dégâts_bruts = (dé - seuil) + bonus_ennemi
    si dragon_coat ET !bypassArmor :
      dégâts_nets = max(0, dégâts_bruts - 5)
    sinon :
      dégâts_nets = dégâts_bruts
    PV_joueur -= dégâts_nets
    │
    ▼
[Vérifier état joueur]
  PV ≤ 5 → MORT (§ 14)
  sinon → retour PHASE JOUEUR
```

---

## 3. Cas spéciaux implémentés dans le code

### 3.1 Loup (§ 21)
```dart
// Dans enemies.json :
"wolf": {
  "dragon_coat_bypassed": true,  // ← clé critique
  "attack_threshold": 6,
  "bonus_damage": 3
}

// Dans CombatNotifier._resolveEnemyAttack() :
final bypassArmor = enemy.playerCoatBypassed;
ref.read(playerStateProvider.notifier)
   .takeDamage(rawDamage, bypassArmor: bypassArmor);
```

### 3.2 Monstre Végétal (§ 35) — frappe en premier
```json
"vegetable_monster": {
  "strikes_first": true,
  "attack_threshold": 5,
  "bonus_damage": 4
}
```
```dart
// Dans CombatNotifier.startCombat() :
if (!data.playerStrikesFirst) {
  _resolveEnemyAttack();  // ← exécuté immédiatement au démarrage
}
```

### 3.3 Ansalom (boss final) — armure magique
```json
"ansalom": {
  "max_hp": 100,
  "armor_points": 20   // ← absorbé avant les PV
}
```
```dart
// Dans _applyDamageToEnemy() :
if (enemyCopy.currentArmor > 0) {
  final armorDamage = damage.clamp(0, enemyCopy.currentArmor);
  enemyCopy.currentArmor -= armorDamage;
  damage -= armorDamage;
}
```

### 3.4 Combat contre deux ennemis simultanés (§ 28 — les Molosses)
Ajouter dans le JSON :
```json
"multi_combat": {
  "enemies": ["mastiff", "mastiff"],
  "initiative_note": "Si épée en main → joueur frappe en premier, sinon ennemi_1 frappe d'abord",
  "turn_order": ["player", "enemy_1", "enemy_2"]
}
```
Étendre `CombatState` :
```dart
class CombatState {
  final List<Enemy> enemies;  // Liste au lieu d'un seul ennemi
  int currentEnemyIndex;      // Tour de quel ennemi
  // ...
}
```

### 3.5 Réaction Amicale
```dart
String tryFriendlyReaction() {
  // Joueur lance 3 fois, ennemi lance 1 fois
  // Succès si MEILLEUR des 3 lancers joueur < lancer ennemi
  final rolls = [roll2d6(), roll2d6(), roll2d6()];
  final best = rolls.reduce(max);
  final enemyRoll = roll2d6();
  
  if (best < enemyRoll) {
    // Succès → traiter comme victoire de combat
    gainXp(1);
    return 'Réaction Amicale réussie !';
  }
  return 'Échec.';
}
```

### 3.6 Corruption (*C, **C, ***C, ****C)
```dart
// Disponible UNIQUEMENT si paragraph.corruptionTier != null
// Et uniquement si player.hasGold(cost)

String tryCorruption(int goldOffered) {
  spendGold(goldOffered);  // L'or est dépensé même en cas d'échec
  final roll = roll2d6();
  if (roll >= 8) {
    // Succès → victoire
    gainXp(1);
  }
  // roll 1-7 → échec (or perdu quand même)
}
```

---

## 4. Données à transcrire depuis le Markdown

### Paragraphes avec combats repérés dans le livre

| § | Ennemi | PV | Seuil | Bonus dégâts | Particularité |
|---|--------|----|-------|-------------|---------------|
| 9/21 | Loup | 20 | 6 | +3 | Dragon coat contourné, joueur 1er (E.J.) |
| 10 | Sanglier | 25 | 6 | +4 | — |
| 27 | Poulets (×N) | — | — | +1 | Lancer 2d6 global, pas combat standard |
| 28 | Molosses ×2 | 20 chacun | 5 | +3 | Multi-combat, épée en main → initiative |
| 29 | Insectes Archers | — | — | — | Pas de combat, jet de fuite uniquement |
| 35 | Monstre Végétal | 35 | 5 | +4 | Frappe en premier |
| ? | Ansalom | 100 | 6 | +8 | Armure 20 pts, boss final |

---

## 5. Intégration des paragraphes spéciaux

### § 14 — Mort (reset)
```dart
// Dans PlayerStateNotifier :
void resetForNewRun(List<InventoryItem> startingInventory) {
  final previousDefeated = state.defeatedEnemies;
  // Conserver les ennemis vaincus (règle du livre)
  // Recalculer les PV (relancer 2d6×4)
  // Perdre tout l'inventaire sauf équipement de départ
}
```

### § "Temps du Rêve" (p. 179)
À implémenter comme paragraphes séparés dans le JSON (`dream_01`, `dream_02`, etc.) avec leurs propres règles de monstres nocturnes.

### Sommeil — Implémentation dans `game_providers.dart`
```dart
SleepResult trySleep() {
  final roll = roll1d6();
  if (roll >= 5) {
    // Sommeil réparateur
    return SleepResult(dreamEncountered: false, healedHp: roll2d6(), roll: roll);
  } else {
    // Rêve (§ p.179)
    return SleepResult(dreamEncountered: true, healedHp: 0, roll: roll);
  }
}
```

---

## 6. Pipeline de conversion Markdown → JSON

### Étape 1 : Parser les numéros de paragraphes
Regex pour détecter le début d'un paragraphe numéroté :
```regex
^(\d+)(\*{0,4}C?)$
```
Exemple : `35*C` → ID = "35", corruptionTier = 1

### Étape 2 : Parser les choix
```regex
Si vous .+?, rendez-vous au (\d+)\.
```
Capture : texte du choix + numéro cible

### Étape 3 : Parser les données de combat
```regex
Il possède (\d+) POINTS DE VIE
il inflige (\d+) Points de Dommage supplémentaires
il suffit d'un (\d+) pour (\w+) frapper
```

### Étape 4 : Script Python de conversion (à exécuter une fois)
```python
import re, json

def parse_graal_markdown(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    paragraphs = {}
    # Séparer par numéro de paragraphe
    pattern = r'^(\d+)(\*{0,4}C?)\s*\n(.*?)(?=^\d+|\Z)'
    matches = re.finditer(pattern, content, re.MULTILINE | re.DOTALL)
    
    for m in matches:
        pid = m.group(1)
        corruption = len(m.group(2).replace('C',''))  # Compter les *
        text = m.group(3).strip()
        
        # Parser les choix
        choices = []
        choice_pattern = r'rendez-vous au (\d+)'
        # ... (logique de parsing à affiner)
        
        paragraphs[pid] = {
            "id": pid,
            "title": f"Paragraphe {pid}",
            "text": text,
            "choices": choices,
            "corruption_tier": corruption if corruption > 0 else None,
            "combat": None,
            "loot": []
        }
    
    return paragraphs
```

---

## 7. Checklist d'implémentation

- [x] Modèles de données (`game_models.dart`)
- [x] Providers Riverpod (`game_providers.dart`)
- [x] Écran principal (`story_screen.dart`)
- [x] Overlay de combat (`combat_overlay.dart`)
- [x] Drawer feuille de personnage (`character_drawer.dart`)
- [x] Écran setup PV (`hp_setup_screen.dart`)
- [x] Boutons de choix conditionnels (`choice_button.dart`)
- [x] JSON de structure du jeu (`game_structure.json`)
- [ ] Transcription des 200+ paragraphes dans le JSON
- [ ] Implémentation § Temps du Rêve
- [ ] Multi-combat (Molosses §28)
- [ ] Boule de Feu (2 charges, 75 dégâts)
- [ ] Sauvegarde automatique (SharedPreferences)
- [ ] Insertion des illustrations (assets/images/)
- [ ] Polices Cinzel + Crimson Text (Google Fonts download)
- [ ] Icône APK 512×512 PNG
- [ ] Build APK : `flutter build apk --release`
