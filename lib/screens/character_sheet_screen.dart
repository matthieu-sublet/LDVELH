// screens/character_sheet_screen.dart — Écran plein de la feuille de personnage
import 'package:flutter/material.dart';
import '../models/game_theme.dart';
import '../widgets/character_drawer.dart';

class CharacterSheetScreen extends StatelessWidget {
  const CharacterSheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraalTheme.background,
      appBar: AppBar(
        title: const Text('Feuille de Pip'),
        backgroundColor: GraalTheme.background,
        foregroundColor: GraalTheme.amber,
      ),
      body: const CharacterDrawer(),
    );
  }
}
