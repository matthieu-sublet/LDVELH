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

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
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
      builder: (context, widget) {
        ErrorWidget.builder = (details) => Scaffold(
          backgroundColor: const Color(0xFF0E0E14),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ Erreur au démarrage',
                    style: TextStyle(color: Color(0xFFFF6B6B),
                      fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(details.exception.toString(),
                    style: const TextStyle(color: Color(0xFFE8DCC8), fontSize: 14)),
                  const SizedBox(height: 12),
                  Text(details.stack.toString(),
                    style: const TextStyle(color: Color(0xFF9A8E78), fontSize: 11)),
                ],
              ),
            ),
          ),
        );
        return widget ?? const SizedBox();
      },
    );
  }
}
