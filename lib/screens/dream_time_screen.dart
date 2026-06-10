// ============================================================
//  screens/dream_time_screen.dart — Interface du Temps du Rêve
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/dream_time_engine.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';

class DreamTimeScreen extends ConsumerStatefulWidget {
  final String returnParagraph;
  const DreamTimeScreen({super.key, required this.returnParagraph});

  @override
  ConsumerState<DreamTimeScreen> createState() => _DreamTimeScreenState();
}

class _DreamTimeScreenState extends ConsumerState<DreamTimeScreen> {
  int? _section;
  DreamResult? _result;
  bool _resolved = false;

  void _rollSection() {
    final section = roll2d6();
    setState(() {
      _section = section;
      _result = null;
      _resolved = false;
    });
  }

  void _resolveSection() {
    if (_section == null) return;
    final result = DreamTimeEngine.resolve(_section!);
    setState(() {
      _result = result;
      _resolved = true;
    });

    // Appliquer les dégâts
    final notifier = ref.read(playerStateProvider.notifier);
    final player = ref.read(playerStateProvider);

    if (!result.survived) {
      // Mort dans le rêve
      notifier.takeDamage(player.currentHp + 999);
    } else if (result.hpLost == -1) {
      // Diviser PV par 2
      final half = (player.currentHp / 2).floor();
      notifier.takeDamage(player.currentHp - half);
    } else if (result.hpLost > 0) {
      notifier.takeDamage(result.hpLost);
    }
    if (result.hpGained > 0) {
      notifier.heal(result.hpGained);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060614),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060614),
        title: const Text('⭐ Le Temps du Rêve',
            style: TextStyle(fontFamily: 'Cinzel', color: GraalTheme.magic, fontSize: 18)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header mystique
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A003A), Color(0xFF0A0A20)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: GraalTheme.magic.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    const Text('✧ ✦ ✧', style: TextStyle(color: GraalTheme.magic, fontSize: 22)),
                    const SizedBox(height: 8),
                    const Text(
                      'Vous sombrez dans le sommeil et entrez dans le Temps du Rêve...\n\n'
                      'Vous êtes sans armure, sans magie, sans armes.\n'
                      'Tout PV perdu ici est définitif. Si vous mourez, c\'est la vraie mort.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Crimson Text', color: GraalTheme.textSecondary,
                        fontSize: 15, height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite, color: GraalTheme.danger, size: 16),
                        const SizedBox(width: 6),
                        Text('PV actuels : ${player.currentHp} / ${player.maxHp}',
                          style: const TextStyle(
                            fontFamily: 'Crimson Text', color: GraalTheme.amberLight,
                            fontSize: 16, fontWeight: FontWeight.bold,
                          )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Étape 1 : Lancer les dés
              if (_section == null) ...[
                const Text('Lancez 2d6 pour choisir votre aventure onirique.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Crimson Text', color: GraalTheme.textPrimary, fontSize: 17)),
                const SizedBox(height: 20),
                _DreamButton(
                  label: '🎲 Lancer les dés du Rêve',
                  color: GraalTheme.magic,
                  onTap: _rollSection,
                ),
              ],

              // Étape 2 : Section tirée, affichage
              if (_section != null && !_resolved) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0020),
                    border: Border.all(color: GraalTheme.magic),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text('Section $_section',
                          style: const TextStyle(
                            fontFamily: 'Cinzel', color: GraalTheme.amberLight,
                            fontSize: 28, fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 8),
                      Text(_sectionTitle(_section!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Crimson Text', color: GraalTheme.textPrimary, fontSize: 17,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _DreamButton(
                  label: '▶ Résoudre cette rencontre',
                  color: GraalTheme.danger,
                  onTap: _resolveSection,
                ),
              ],

              // Étape 3 : Résultat
              if (_resolved && _result != null) ...[
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _result!.survived ? const Color(0xFF001A00) : const Color(0xFF1A0000),
                        border: Border.all(
                          color: _result!.survived ? GraalTheme.success : GraalTheme.danger,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _result!.survived ? '🌅 Vous vous réveillez...' : '☠️ Mort dans le Rêve.',
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: _result!.survived ? GraalTheme.success : GraalTheme.dangerLight,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _result!.narrative,
                            style: const TextStyle(
                              fontFamily: 'Crimson Text', color: GraalTheme.textPrimary,
                              fontSize: 15, height: 1.5,
                            ),
                          ),
                          if (_result!.hpLost > 0 && _result!.survived) ...[
                            const SizedBox(height: 8),
                            Text('⚠️ PV perdus dans le Rêve : ${_result!.hpLost}',
                                style: const TextStyle(color: GraalTheme.amber, fontFamily: 'Crimson Text', fontSize: 15)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_result!.survived)
                  _DreamButton(
                    label: '🌄 Retourner à l\'aventure',
                    color: GraalTheme.amber,
                    onTap: () => Navigator.of(context).pop(true),
                  )
                else
                  _DreamButton(
                    label: '☠️ Aller au § 14 (Mort)',
                    color: GraalTheme.danger,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _sectionTitle(int s) {
    const titles = {
      2: 'Le Ronge-Méninges — combat sans armure ni arme.',
      3: 'Le Vampire — course-poursuite dans un cimetière.',
      4: 'Les Deux Calices — vin ou poison ?',
      5: 'La Chute de la Tour — escalade périlleuse.',
      6: 'La Chute de la Tour — escalade périlleuse.',
      7: 'Les Abeilles (ou le Céleri) — nature déchaînée.',
      8: 'Le Chevalier Noir — duel à la lance.',
      9: 'Le Monstre du Sommeil — le choix des coffrets.',
      10: 'L\'Ogre et les Sept Flèches — sauvez la jeune fille.',
      11: 'L\'Oubliette du Roi Arthur — punition injuste.',
      12: 'La Bataille Magique — duel d\'ondes sur deux montagnes.',
    };
    return titles[s] ?? 'Rencontre mystérieuse.';
  }
}

class _DreamButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DreamButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'Crimson Text', color: color, fontSize: 16)),
      ),
    );
  }
}
