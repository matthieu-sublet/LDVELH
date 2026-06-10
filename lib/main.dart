// ============================================================
//  main.dart  —  La Quête du Graal : Le Château des Ténèbres
//  Architecture : Flutter + Riverpod + flutter_markdown
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/story_screen.dart';
import 'screens/character_sheet_screen.dart';
import 'screens/dream_time_screen.dart';
import 'models/game_theme.dart';
import 'providers/persistence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forcer portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Pré-charger SharedPreferences pour la sauvegarde
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Injecter l'instance SharedPreferences synchrone
        sharedPreferencesProvider.overrideWith((_) async => prefs),
      ],
      child: const GraalApp(),
    ),
  );
}

class GraalApp extends StatelessWidget {
  const GraalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Château des Ténèbres',
      debugShowCheckedModeBanner: false,
      theme: GraalTheme.darkFantasy,
      initialRoute: '/',
      routes: {
        '/': (context) => const StoryScreen(),
        '/character': (context) => const CharacterSheetScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/dream') {
          final returnParagraph = settings.arguments as String? ?? 'intro';
          return MaterialPageRoute(
            builder: (_) => DreamTimeScreen(returnParagraph: returnParagraph),
          );
        }
        return null;
      },
    );
  }
}
