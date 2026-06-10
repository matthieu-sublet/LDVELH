import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatefulWidget {
  const TestApp({super.key});
  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  String _status = 'Chargement...';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _testLoad();
  }

  Future<void> _testLoad() async {
    try {
      setState(() => _status = 'Test 1 : Flutter OK');
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() => _status = 'Test 2 : Chargement JSON...');
      final raw = await rootBundle.loadString('assets/data/game_structure.json');

      setState(() => _status = 'Test 3 : Parsing JSON...');
      final data = jsonDecode(raw);

      setState(() => _status =
        '✅ Tout OK !\n'
        'Paragraphes : ${(data["paragraphs"] as Map).length}\n'
        'JSON size : ${raw.length} chars');
    } catch (e, stack) {
      setState(() {
        _status = '❌ ERREUR';
        _error = '$e\n\n$stack';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0E0E14),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_status,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_error,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B), fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
