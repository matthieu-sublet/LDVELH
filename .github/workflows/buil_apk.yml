#!/usr/bin/env bash
# ============================================================
#  build_apk.sh — Script de build APK complet
#  Conditions préalables :
#    • Flutter SDK installé et dans le PATH
#    • Java JDK 17+ installé
#    • Android SDK installé (SDK 33+)
#  Usage : bash build_apk.sh
# ============================================================

set -e  # Arrêt sur erreur

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo ""
echo "══════════════════════════════════════════════"
echo "  🏰 BUILD APK — Le Château des Ténèbres"
echo "══════════════════════════════════════════════"
echo ""

# ── 1. Vérifications ────────────────────────────────────────
echo "▶ Vérification de Flutter..."
flutter --version | head -1
echo ""

# ── 2. Générer le JSON depuis le Markdown ───────────────────
echo "▶ Génération du fichier game_structure.json..."
python3 parse_graal.py source.md assets/data/game_structure.json
echo ""

# ── 3. Vérifier les polices ──────────────────────────────────
echo "▶ Vérification des polices..."
FONTS_DIR="assets/fonts"
REQUIRED_FONTS=(
    "Cinzel-Regular.ttf"
    "Cinzel-SemiBold.ttf"
    "Cinzel-Bold.ttf"
    "CrimsonText-Regular.ttf"
    "CrimsonText-SemiBold.ttf"
    "CrimsonText-Italic.ttf"
)

mkdir -p "$FONTS_DIR"
ALL_FONTS_OK=true
for font in "${REQUIRED_FONTS[@]}"; do
    if [ ! -f "$FONTS_DIR/$font" ]; then
        echo "  ⚠️  Police manquante : $FONTS_DIR/$font"
        ALL_FONTS_OK=false
    else
        echo "  ✅ $font"
    fi
done

if [ "$ALL_FONTS_OK" = false ]; then
    echo ""
    echo "  💡 Télécharger depuis Google Fonts :"
    echo "     https://fonts.google.com/specimen/Cinzel"
    echo "     https://fonts.google.com/specimen/Crimson+Text"
    echo "  Placer les fichiers .ttf dans : $FONTS_DIR/"
    echo ""
    echo "  Le build continue avec les polices système de secours..."
fi
echo ""

# ── 4. Vérifier l'icône d'application ───────────────────────
echo "▶ Vérification de l'icône..."
mkdir -p assets/icon
if [ ! -f "assets/icon/app_icon.png" ]; then
    echo "  ⚠️  Icône manquante : assets/icon/app_icon.png (512×512 PNG requis)"
    echo "  💡 Créer une icône 512×512 et la placer ici : assets/icon/app_icon.png"
    echo "  Le build continue sans icône personnalisée..."
else
    echo "  ✅ Icône trouvée"
    echo "  Génération des icônes Android..."
    dart run flutter_launcher_icons
fi
echo ""

# ── 5. Nettoyer le build précédent ──────────────────────────
echo "▶ Nettoyage..."
flutter clean
echo ""

# ── 6. Récupérer les dépendances ────────────────────────────
echo "▶ flutter pub get..."
flutter pub get
echo ""

# ── 7. Build APK release ────────────────────────────────────
echo "▶ Build APK release..."
flutter build apk \
    --release \
    --split-debug-info=./build/debug-info \
    --obfuscate

echo ""
echo "══════════════════════════════════════════════"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    SIZE=$(du -sh "$APK_PATH" | cut -f1)
    echo "  ✅ APK généré avec succès !"
    echo "  📦 Emplacement : $APK_PATH"
    echo "  📏 Taille      : $SIZE"
    echo ""
    echo "  Installation sur appareil connecté :"
    echo "    adb install $APK_PATH"
    echo ""
    echo "  Copier l'APK sur le téléphone :"
    echo "    cp $APK_PATH ~/Bureau/chateau_tenebres.apk"
else
    echo "  ❌ Échec : APK non trouvé."
    echo "  Consultez les logs ci-dessus."
fi

echo "══════════════════════════════════════════════"
echo ""
