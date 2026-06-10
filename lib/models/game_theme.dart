// ============================================================
//  models/game_theme.dart  —  Thème Dark Fantasy
// ============================================================

import 'package:flutter/material.dart';

class GraalTheme {
  // ─── Palette ───────────────────────────────────────────────
  static const Color background      = Color(0xFF0E0E14); // Noir encre
  static const Color surface         = Color(0xFF1A1A24); // Surface foncée
  static const Color surfaceVariant  = Color(0xFF22222F); // Cartes, drawers
  static const Color divider         = Color(0xFF2E2E40);
  static const Color amber           = Color(0xFFD4A017); // Boutons principaux
  static const Color amberLight      = Color(0xFFFFD166); // Hover / selected
  static const Color textPrimary     = Color(0xFFE8DCC8); // Parchemin clair
  static const Color textSecondary   = Color(0xFF9A8E78); // Texte secondaire
  static const Color textDim         = Color(0xFF5A5040); // Texte grisé
  static const Color danger          = Color(0xFFB22222); // PV, dommages
  static const Color dangerLight     = Color(0xFFFF6B6B);
  static const Color success         = Color(0xFF2E7D32); // Victoire, gain PV
  static const Color magic           = Color(0xFF6A0DAD);  // Magie, Doigt de Feu
  static const Color gold            = Color(0xFFFFD700); // Or, pièces

  static ThemeData get darkFantasy => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: amber,
      secondary: amberLight,
      surface: surface,
      error: danger,
      onPrimary: Color(0xFF0E0E14),
      onSecondary: Color(0xFF0E0E14),
      onSurface: textPrimary,
      onError: textPrimary,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0E0E14),
      foregroundColor: amber,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cinzel',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: amber,
        letterSpacing: 1.5,
      ),
      iconTheme: IconThemeData(color: amber),
    ),

    // Drawer
    drawerTheme: const DrawerThemeData(
      backgroundColor: surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
    ),

    // Boutons ElevatedButton → Choix de navigation
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E1A0E),
        foregroundColor: amber,
        disabledBackgroundColor: const Color(0xFF1A1A1A),
        disabledForegroundColor: textDim,
        side: const BorderSide(color: amber, width: 1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Crimson Text',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        elevation: 0,
      ),
    ),

    // TextButton → Actions secondaires (dormir, corrompre, etc.)
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textSecondary,
        textStyle: const TextStyle(
          fontFamily: 'Crimson Text',
          fontSize: 14,
        ),
      ),
    ),

    // Card → Encart ennemi, inventaire
    cardTheme: const CardTheme(
      color: surfaceVariant,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        side: BorderSide(color: divider, width: 1),
      ),
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: divider,
      thickness: 1,
      space: 24,
    ),

    // SnackBar
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: surfaceVariant,
      contentTextStyle: TextStyle(
        fontFamily: 'Crimson Text',
        color: textPrimary,
        fontSize: 15,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // Texte global
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Cinzel',
        color: amber,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Cinzel',
        color: amber,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Cinzel',
        color: amberLight,
        fontSize: 16,
        letterSpacing: 0.8,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Crimson Text',
        color: textPrimary,
        fontSize: 18,
        height: 1.7,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Crimson Text',
        color: textSecondary,
        fontSize: 16,
        height: 1.6,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Crimson Text',
        color: amber,
        fontSize: 15,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),

    fontFamily: 'Crimson Text',
  );
}
