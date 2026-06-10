# 🏰 La Quête du Graal — Le Château des Ténèbres
## Application Flutter — Guide complet d'installation et de build

---

## Architecture du projet

```
graal_flutter/
├── lib/
│   ├── main.dart                        ← Point d'entrée, routing
│   ├── models/
│   │   ├── game_models.dart             ← Tous les types (Paragraph, Enemy, PlayerState…)
│   │   └── game_theme.dart              ← Palette Dark Fantasy, ThemeData
│   ├── providers/
│   │   ├── game_providers.dart          ← Riverpod : état joueur, moteur de combat
│   │   └── persistence_service.dart    ← SharedPreferences : save/load
│   ├── engine/
│   │   ├── multi_combat_engine.dart    ← Combats N vs 1 (Molosses, Zombies…)
│   │   └── dream_time_engine.dart      ← 11 rencontres du Temps du Rêve
│   ├── screens/
│   │   ├── story_screen.dart           ← Écran principal (paragraphes + choix)
│   │   ├── dream_time_screen.dart      ← Écran du Temps du Rêve
│   │   └── character_sheet_screen.dart ← Feuille de personnage plein écran
│   └── widgets/
│       ├── character_drawer.dart       ← Drawer latéral (stats, inventaire, règles)
│       ├── choice_button.dart          ← Bouton de choix animé avec conditions
│       ├── combat_overlay.dart         ← Overlay combat 1v1
│       ├── multi_combat_overlay.dart   ← Overlay combat multi-ennemis
│       ├── hp_setup_screen.dart        ← Écran de création de personnage
│       └── loot_dialog.dart            ← Dialog de butin
├── assets/
│   ├── data/
│   │   └── game_structure.json         ← Généré par parse_graal.py (160 paragraphes)
│   ├── fonts/                          ← Cinzel + Crimson Text (à télécharger)
│   ├── icon/                           ← app_icon.png 512×512
│   └── images/
│       ├── paragraphs/                 ← p{id}.png (optionnel)
│       └── enemies/                    ← wolf.png, spider.png… (optionnel)
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/com/graal/chateau_tenebres/MainActivity.kt
│   │       └── res/
│   │           ├── values/styles.xml
│   │           └── drawable/launch_background.xml
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle.properties
├── parse_graal.py                       ← Convertisseur Markdown → JSON
├── build_apk.sh                         ← Script de build APK en une commande
└── pubspec.yaml                         ← Dépendances Flutter
```

---

## Étape 1 — Prérequis

### 1.1 Flutter SDK
```bash
# Vérifier Flutter
flutter --version
# Requis : Flutter 3.10+ / Dart 3.0+

# Si pas installé :
# https://docs.flutter.dev/get-started/install/linux
```

### 1.2 Android SDK
- Android Studio ou ligne de commande
- SDK Platform 33 (Android 13) minimum
- Build Tools 34.0.0

```bash
# Vérifier
flutter doctor
# Tout doit être ✓ pour Android toolchain
```

### 1.3 Java
```bash
java -version
# Requis : Java 17+
```

---

## Étape 2 — Polices Google Fonts

Les polices ne sont **pas** incluses dans le dépôt (droits). À télécharger :

### Cinzel
1. Aller sur https://fonts.google.com/specimen/Cinzel
2. Télécharger la famille
3. Copier dans `assets/fonts/` :
   - `Cinzel-Regular.ttf`
   - `Cinzel-SemiBold.ttf`
   - `Cinzel-Bold.ttf`

### Crimson Text
1. Aller sur https://fonts.google.com/specimen/Crimson+Text
2. Télécharger la famille
3. Copier dans `assets/fonts/` :
   - `CrimsonText-Regular.ttf`
   - `CrimsonText-SemiBold.ttf`
   - `CrimsonText-Italic.ttf`

> Si vous voulez ignorer les polices custom pour tester rapidement, retirez
> la section `fonts:` du `pubspec.yaml` — Flutter utilisera la police système.

---

## Étape 3 — Icône de l'application

Créer une image PNG **512 × 512** pixels et la placer ici :
```
assets/icon/app_icon.png
```

Puis générer les icônes Android automatiquement :
```bash
dart run flutter_launcher_icons
```

> Sans icône, l'APK utilisera l'icône Flutter par défaut. Aucun bug.

---

## Étape 4 — Générer le JSON des paragraphes

Le fichier `assets/data/game_structure.json` est **déjà généré** et inclus.
Si vous modifiez le Markdown source, régénérez avec :

```bash
python3 parse_graal.py source.md assets/data/game_structure.json
```

Le script produit :
- 160 paragraphes parsés automatiquement
- 19 définitions d'ennemis
- 18 paragraphes avec combats intégrés
- 10 paragraphes avec loot

Pour **ajouter/corriger des paragraphes** manuellement, éditez directement
`game_structure.json` en respectant le schéma défini dans `_notes_for_developer`.

---

## Étape 5 — Build APK

### Option A : Script automatique (recommandé)
```bash
bash build_apk.sh
```

### Option B : Commandes manuelles
```bash
# Installer les dépendances
flutter pub get

# Build release APK
flutter build apk --release

# APK produit ici :
# build/app/outputs/flutter-apk/app-release.apk
```

### Option C : Build debug (pour tester sans signature)
```bash
flutter build apk --debug
# APK ici : build/app/outputs/flutter-apk/app-debug.apk
```

---

## Étape 6 — Installer sur un appareil Android

### Via ADB (appareil connecté en USB avec débogage USB activé)
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Via transfert de fichier
1. Copier l'APK sur le téléphone
2. Ouvrir le fichier APK sur le téléphone
3. Autoriser l'installation depuis des sources inconnues si demandé
4. Installer

### Via flutter run (en développement)
```bash
# Lancer directement sur appareil connecté
flutter run

# Mode release sur appareil
flutter run --release
```

---

## Dépendances pubspec.yaml

| Package | Version | Usage |
|---------|---------|-------|
| `flutter_riverpod` | ^2.4.9 | State management |
| `flutter_markdown` | ^0.6.18 | Rendu texte paragraphes |
| `shared_preferences` | ^2.2.2 | Sauvegarde automatique |
| `flutter_launcher_icons` | ^0.13.1 | Génération icônes Android |

---

## Ajouter des illustrations

Les illustrations sont **optionnelles**. Pour en ajouter :

1. Créer un fichier PNG pour le paragraphe 42 :
   ```
   assets/images/paragraphs/p42.png
   ```

2. Le moteur tente de charger `assets/images/paragraphs/p{id}.png`
   pour chaque paragraphe. Si absent, rien ne s'affiche (pas d'erreur).

3. Pour les ennemis :
   ```
   assets/images/enemies/wolf.png
   assets/images/enemies/spider.png
   assets/images/enemies/ansalom.png
   ```

4. Déclarer dans `pubspec.yaml` (déjà fait) :
   ```yaml
   assets:
     - assets/images/
     - assets/images/paragraphs/
     - assets/images/enemies/
   ```

---

## Taille APK estimée

| Contenu | Taille |
|---------|--------|
| Code Flutter compilé | ~6 MB |
| JSON paragraphes | ~1 MB |
| Polices (si incluses) | ~2 MB |
| **Sans illustrations** | **~9 MB** |
| Avec illustrations (40+ PNG) | ~25–50 MB |

---

## Résolution de problèmes courants

### `flutter: command not found`
→ Ajouter Flutter au PATH : `export PATH="$PATH:/chemin/vers/flutter/bin"`

### `SDK location not found`
→ Créer `android/local.properties` :
```
sdk.dir=/home/USER/Android/Sdk
flutter.sdk=/home/USER/flutter
```

### `Minimum SDK version`
→ Dans `android/app/build.gradle`, vérifier `minSdkVersion 21`.

### Police non trouvée au runtime
→ Vérifier les noms exacts dans `pubspec.yaml` vs fichiers dans `assets/fonts/`.
   Les noms sont **sensibles à la casse**.

### `PlatformException shared_preferences`
→ Vérifier `minSdkVersion >= 16` dans le build.gradle.

---

## Checklist avant de distribuer l'APK

- [ ] `flutter doctor` tout vert
- [ ] `python3 parse_graal.py` exécuté avec succès (160 §)
- [ ] Polices Cinzel + Crimson Text dans `assets/fonts/`
- [ ] Icône 512×512 dans `assets/icon/app_icon.png`
- [ ] `dart run flutter_launcher_icons` exécuté
- [ ] `flutter build apk --release` sans erreur
- [ ] APK testé sur un vrai appareil Android
- [ ] Navigation intro → §8 → §9 → combat loup vérifiée
- [ ] Sauvegarde/restauration vérifiée (tuer l'app, relancer)
- [ ] Temps du Rêve accessible depuis le menu 💤
