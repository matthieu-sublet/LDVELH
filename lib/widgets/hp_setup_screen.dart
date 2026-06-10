// ============================================================
//  widgets/hp_setup_screen.dart  —  Création du personnage
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';

class HpSetupScreen extends StatefulWidget {
  final void Function(int hp, List<InventoryItem> inventory) onConfirm;

  const HpSetupScreen({super.key, required this.onConfirm});

  @override
  State<HpSetupScreen> createState() => _HpSetupScreenState();
}

class _HpSetupScreenState extends State<HpSetupScreen> {
  int _rolledHp = 0;
  int _rollCount = 0;
  final int _maxRolls = 3;
  List<int> _rolls = [];

  void _roll() {
    if (_rollCount >= _maxRolls) return;
    final rng = Random();
    final d1 = rng.nextInt(6) + 1;
    final d2 = rng.nextInt(6) + 1;
    final result = (d1 + d2) * 4;

    setState(() {
      _rollCount++;
      _rolls.add(result);
      _rolledHp = _rolls.reduce((a, b) => a > b ? a : b);
    });
  }

  List<InventoryItem> _buildStartingInventory() {
    return [
      InventoryItem(
        id: 'ej',
        name: 'Excalibur Junior (E.J.)',
        type: ItemType.weapon,
        description: 'Épée magique de Merlin. Seuil d\'attaque : 4. +5 dégâts.',
        attackThresholdOverride: 4,
        bonusDamage: 5,
      ),
      InventoryItem(
        id: 'dagger',
        name: 'Dague',
        type: ItemType.weapon,
        description: '+2 dégâts supplémentaires.',
        bonusDamage: 2,
      ),
      InventoryItem(
        id: 'dragon_coat',
        name: 'Pourpoint en peau de dragon',
        type: ItemType.armor,
        description: 'Réduit les dégâts reçus de 5 points.',
        damageReduction: 5,
      ),
      InventoryItem(
        id: 'healing_potion',
        name: 'Potion Curative (3 fioles × 6 doses)',
        type: ItemType.consumable,
        description: 'Récupère 2d6 PV par dose.',
        usesRemaining: 18,
        usesTotal: 18,
        effect: 'heal_2d6',
      ),
      InventoryItem(
        id: 'fire_finger_right',
        name: 'Doigt de Feu 1 (main droite)',
        type: ItemType.magic,
        description: '10 dégâts garantis. 5 utilisations.',
        usesRemaining: 5,
        usesTotal: 5,
        effect: 'damage_10_no_roll',
      ),
      InventoryItem(
        id: 'fire_finger_left',
        name: 'Doigt de Feu 2 (main gauche)',
        type: ItemType.magic,
        description: '10 dégâts garantis. 5 utilisations.',
        usesRemaining: 5,
        usesTotal: 5,
        effect: 'damage_10_no_roll',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraalTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Text(
                '⚜️',
                style: TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'LA QUÊTE DU GRAAL',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: GraalTheme.amber,
                  fontSize: 22,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Le Château des Ténèbres',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: GraalTheme.textSecondary,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GraalTheme.surfaceVariant,
                  border: Border.all(color: GraalTheme.divider),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ÉTABLIR VOS POINTS DE VIE',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: GraalTheme.amberLight,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lancez deux dés, additionnez et multipliez par 4.\n'
                      'Vous pouvez relancer jusqu\'à 3 fois et garder le meilleur résultat.',
                      style: TextStyle(
                        fontFamily: 'Crimson Text',
                        color: GraalTheme.textSecondary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Affichage des lancers
                    if (_rolls.isNotEmpty)
                      Column(
                        children: [
                          ..._rolls.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Lancer ${e.key + 1} : ',
                                  style: const TextStyle(color: GraalTheme.textSecondary, fontSize: 15),
                                ),
                                Text(
                                  '${e.value} PV',
                                  style: TextStyle(
                                    color: e.value == _rolledHp
                                        ? GraalTheme.amberLight
                                        : GraalTheme.textDim,
                                    fontSize: 15,
                                    fontWeight: e.value == _rolledHp
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (e.value == _rolledHp)
                                  const Text(' ✓',
                                      style: TextStyle(color: GraalTheme.success)),
                              ],
                            ),
                          )),
                          const SizedBox(height: 16),
                          Text(
                            _rolledHp > 0 ? 'Meilleur résultat : $_rolledHp PV' : '',
                            style: const TextStyle(
                              fontFamily: 'Cinzel',
                              color: GraalTheme.amber,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (_rollCount < _maxRolls)
                      ElevatedButton.icon(
                        onPressed: _roll,
                        icon: const Text('🎲', style: TextStyle(fontSize: 20)),
                        label: Text(
                          _rollCount == 0
                              ? 'Lancer les dés'
                              : 'Relancer (${_maxRolls - _rollCount} restant${_maxRolls - _rollCount > 1 ? 's' : ''})',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                    if (_rolledHp > 0) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => widget.onConfirm(
                            _rolledHp,
                            _buildStartingInventory(),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: GraalTheme.amber,
                            foregroundColor: GraalTheme.background,
                          ),
                          child: Text(
                            'Commencer avec $_rolledHp PV',
                            style: const TextStyle(
                              fontFamily: 'Cinzel',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Équipement de départ résumé
              const _StartingGearSummary(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartingGearSummary extends StatelessWidget {
  const _StartingGearSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GraalTheme.surfaceVariant,
        border: Border.all(color: GraalTheme.divider),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ÉQUIPEMENT DE DÉPART', style: TextStyle(
            fontFamily: 'Cinzel', color: GraalTheme.amber,
            fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          const _GearLine('⚔️ Excalibur Junior (E.J.)', 'Seuil 4, +5 dégâts'),
          const _GearLine('🗡️ Dague', '+2 dégâts'),
          const _GearLine('🛡️ Pourpoint en peau de dragon', '-5 dégâts reçus'),
          const _GearLine('🧪 Potions Curatives', '3 fioles × 6 doses (2d6 PV)'),
          const _GearLine('✨ Doigt de Feu ×2', '5 charges/main, 10 dégâts garanti'),
        ],
      ),
    );
  }
}

class _GearLine extends StatelessWidget {
  final String name;
  final String stat;
  const _GearLine(this.name, this.stat);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(
            fontFamily: 'Crimson Text', color: GraalTheme.textPrimary, fontSize: 14)),
          Text(stat, style: const TextStyle(
            fontFamily: 'Crimson Text', color: GraalTheme.amber, fontSize: 13)),
        ],
      ),
    );
  }
}
