// ============================================================
//  screens/story_screen.dart  —  Écran principal du jeu
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/game_models.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';
import '../providers/persistence_service.dart';
import '../widgets/character_drawer.dart';
import '../widgets/combat_overlay.dart';
import '../engine/multi_combat_engine.dart';
import '../widgets/multi_combat_overlay.dart';
import '../widgets/hp_setup_screen.dart';
import '../widgets/choice_button.dart';
import '../widgets/loot_dialog.dart';

class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({super.key});

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late AnimationController _fade;
  late Animation<double> _fadeAnim;
  bool _lootShown = false; // évite le double affichage du loot

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeIn);
    _fade.forward();

    // Charger la sauvegarde au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSave());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _fade.dispose();
    super.dispose();
  }

  // ── Chargement de la sauvegarde ─────────────────────────

  void _loadSave() {
    final svc = ref.read(persistenceServiceProvider);
    if (svc == null || !svc.hasSave) return;
    final saved = svc.loadState();
    if (saved == null || saved.maxHp == 0) return;

    // Restaurer l'état sauvegardé
    final notifier = ref.read(playerStateProvider.notifier);
    // Méthode de restauration directe via le provider
    ref.read(playerStateProvider.notifier).restoreFrom(saved);
  }

  // ── Navigation ───────────────────────────────────────────

  void _navigateTo(String paragraphId, {bool resetGame = false}) async {
    final notifier = ref.read(playerStateProvider.notifier);
    await _fade.reverse();
    setState(() => _lootShown = false);

    if (resetGame) {
      notifier.resetForNewRun(_startingInventory());
      // Re-lancer la config PV
      notifier.setStartingHp(0);
      _fade.forward();
      return;
    }

    // Temps du Rêve → écran dédié
    if (paragraphId == 'dream_time') {
      final currentId = ref.read(playerStateProvider).currentParagraphId;
      _fade.forward();
      final survived = await Navigator.of(context).pushNamed('/dream', arguments: currentId);
      if (survived == false) notifier.navigateTo('14');
      _scrollTop();
      _fade.forward();
      return;
    }

    notifier.navigateTo(paragraphId);
    _scrollTop();

    // Auto-save
    ref.read(persistenceServiceProvider)?.saveState(ref.read(playerStateProvider));

    await _fade.forward();
  }

  void _scrollTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // ── Sommeil ──────────────────────────────────────────────

  void _trySleep() async {
    final result = trySleep();
    final notifier = ref.read(playerStateProvider.notifier);

    if (result.dreamEncountered) {
      _showSnack('😴 Résultat ${result.roll} — Vous entrez dans le Temps du Rêve…', GraalTheme.magic);
      await Future.delayed(const Duration(milliseconds: 800));
      _navigateTo('dream_time');
    } else {
      notifier.heal(result.healedHp);
      _showSnack('💤 Sommeil réparateur. +${result.healedHp} PV.', GraalTheme.success);
    }
  }

  // ── Potion ───────────────────────────────────────────────

  void _usePotion() {
    final player = ref.read(playerStateProvider);
    final p = player.inventory.firstWhere((i) => i.id == 'healing_potion',
      orElse: () => InventoryItem(id:'_none',name:'',type:ItemType.consumable,description:''));
    if (p.id == '_none' || p.usesRemaining <= 0) {
      _showSnack('Aucune Potion disponible.', GraalTheme.danger); return;
    }
    ref.read(playerStateProvider.notifier).useConsumable('healing_potion');
    _showSnack('🧪 Potion prise ! (${p.usesRemaining - 1} doses restantes)', GraalTheme.success);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color,
          duration: const Duration(seconds: 3)));
  }

  // ── Loot auto-check ──────────────────────────────────────

  void _maybeShowLoot(Paragraph para) {
    if (_lootShown) return;
    if (para.loot.isEmpty) return;
    final notifier = ref.read(playerStateProvider.notifier);
    if (notifier.isLootCollected(para.id)) return;

    setState(() => _lootShown = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => LootDialog(
          paragraphId: para.id,
          loot: para.loot,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    });
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerStateProvider);
    final paragraphsAsync = ref.watch(paragraphsProvider);
    final combat = ref.watch(combatProvider);
    final multiCombat = ref.watch(multiCombatEngineProvider);

    // Écran de setup PV
    if (player.maxHp == 0) {
      return HpSetupScreen(
        onConfirm: (hp, inv) {
          ref.read(playerStateProvider.notifier).setStartingHp(hp);
          for (final item in inv) ref.read(playerStateProvider.notifier).addItem(item);
          ref.read(playerStateProvider.notifier).navigateTo('intro');
        },
      );
    }

    return Scaffold(
      backgroundColor: GraalTheme.background,
      drawer: const CharacterDrawer(),
      appBar: _buildAppBar(player),
      body: Stack(children: [

        // ── Contenu principal ────────────────────────────
        paragraphsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: GraalTheme.amber)),
          error: (e, _) => Center(child: Text('Erreur : $e',
              style: const TextStyle(color: GraalTheme.danger))),
          data: (paras) {
            final para = paras[player.currentParagraphId];
            if (para == null) {
              return Center(child: Text(
                '⚠️ Paragraphe "${player.currentParagraphId}" introuvable.\n'
                'Vérifiez game_structure.json',
                textAlign: TextAlign.center,
                style: const TextStyle(color: GraalTheme.danger, fontFamily: 'Crimson Text', fontSize: 16),
              ));
            }

            // Loot auto-popup
            if (para.loot.isNotEmpty) _maybeShowLoot(para);

            return FadeTransition(
              opacity: _fadeAnim,
              child: _ParagraphView(
                paragraph: para,
                scrollController: _scroll,
                onChoice: (choice) => _buildChoiceButton(choice, player),
                onStartCombat: _startCombat,
                onStartMultiCombat: _startMultiCombat,
              ),
            );
          },
        ),

        // ── Overlay combat simple ────────────────────────
        if (combat.phase != CombatPhase.idle)
          CombatOverlay(
            onCombatEnd: (won, target) {
              ref.read(combatProvider.notifier).reset();
              _navigateTo(target);
            },
          ),

        // ── Overlay multi-combat ─────────────────────────
        if (multiCombat.phase != MultiCombatPhase.idle)
          MultiCombatOverlay(
            onCombatEnd: (won, target) {
              ref.read(multiCombatEngineProvider.notifier).reset();
              _navigateTo(target);
            },
          ),
      ]),
    );
  }

  // ── AppBar ────────────────────────────────────────────────

  AppBar _buildAppBar(PlayerState player) {
    final ratio = player.maxHp > 0 ? player.currentHp / player.maxHp : 0.0;
    final hpColor = ratio > .5 ? GraalTheme.success : ratio > .25 ? GraalTheme.amber : GraalTheme.dangerLight;

    return AppBar(
      backgroundColor: GraalTheme.background,
      leading: Builder(builder: (ctx) => IconButton(
        icon: const Icon(Icons.menu_book_rounded, color: GraalTheme.amber),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
        tooltip: 'Feuille de personnage',
      )),
      title: const Text('Le Château des Ténèbres',
          style: TextStyle(fontFamily: 'Cinzel', color: GraalTheme.amber, fontSize: 16, letterSpacing: 1.2)),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(children: [
            Icon(Icons.favorite, color: hpColor, size: 14),
            const SizedBox(width: 3),
            Text('${player.currentHp}/${player.maxHp}',
              style: TextStyle(fontFamily:'Crimson Text', color:hpColor, fontSize:13, fontWeight:FontWeight.bold)),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: GraalTheme.amber),
          color: GraalTheme.surfaceVariant,
          onSelected: (v) { if (v == 'sleep') _trySleep(); if (v == 'potion') _usePotion(); },
          itemBuilder: (_) => const [
            PopupMenuItem(value:'sleep', child: Text('💤 Dormir', style: TextStyle(color:GraalTheme.textPrimary))),
            PopupMenuItem(value:'potion', child: Text('🧪 Potion Curative', style: TextStyle(color:GraalTheme.textPrimary))),
          ],
        ),
      ],
    );
  }

  // ── Bouton de choix conditionnel ─────────────────────────

  Widget _buildChoiceButton(ParagraphChoice choice, PlayerState player) {
    final itemOk = choice.requiresItem == null || player.hasItem(choice.requiresItem!);
    final goldOk = choice.requiresGold == null || player.hasGold(choice.requiresGold!);
    final ok = itemOk && goldOk;

    if (!ok && choice.hiddenIfMissing) return const SizedBox.shrink();

    String label = choice.text;
    if (!itemOk) label += '\n  [Objet requis : ${choice.requiresItem}]';
    if (!goldOk) label += '\n  [Or requis : ${choice.requiresGold} P.O.]';

    return ChoiceButton(
      label: label,
      enabled: ok,
      onTap: ok ? () => _navigateTo(choice.targetParagraph, resetGame: choice.resetsGame) : null,
    );
  }

  // ── Lancement de combat ───────────────────────────────────

  void _startCombat(CombatData data) {
    ref.read(enemiesProvider).whenData((enemies) {
      final enemy = enemies[data.enemyId];
      if (enemy == null) return;
      // Multi-combat ?
      if ((data.multiCount) > 1) {
        _startMultiCombat(data, enemy);
      } else {
        ref.read(combatProvider.notifier).startCombat(data, enemy);
      }
    });
  }

  void _startMultiCombat(CombatData data, Enemy template) {
    final enemies = List.generate(data.multiCount, (_) => template.clone());
    ref.read(multiCombatEngineProvider.notifier).start(
      enemies: enemies,
      playerFirst: data.playerStrikesFirst ?? true,
      onWin: data.onWinParagraph,
      onDeath: data.onDeathParagraph,
      zombieRule: data.special == 'zombie_kill_only_on_9_12',
    );
  }

  // ── Inventaire de départ ──────────────────────────────────

  static List<InventoryItem> _startingInventory() => [
    InventoryItem(id:'ej',name:'Excalibur Junior (E.J.)',type:ItemType.weapon,
      description:'Seuil 4, +5 dégâts.',attackThresholdOverride:4,bonusDamage:5),
    InventoryItem(id:'dagger',name:'Dague',type:ItemType.weapon,description:'+2 dégâts.',bonusDamage:2),
    InventoryItem(id:'dragon_coat',name:'Pourpoint en peau de dragon',type:ItemType.armor,
      description:'-5 dégâts reçus.',damageReduction:5),
    InventoryItem(id:'healing_potion',name:'Potion Curative',type:ItemType.consumable,
      description:'2d6 PV.',usesRemaining:18,usesTotal:18,effect:'heal_2d6'),
    InventoryItem(id:'fire_finger_right',name:'Doigt de Feu 1',type:ItemType.magic,
      description:'10 dégâts garantis.',usesRemaining:5,usesTotal:5,effect:'damage_10_no_roll'),
    InventoryItem(id:'fire_finger_left',name:'Doigt de Feu 2',type:ItemType.magic,
      description:'10 dégâts garantis.',usesRemaining:5,usesTotal:5,effect:'damage_10_no_roll'),
    InventoryItem(id:'sandwich',name:'Sandwich au rosbif',type:ItemType.quest,
      description:'Pour amadouer les loups.',usesRemaining:1,usesTotal:1),
  ];
}

// ════════════════════════════════════════════════════════════
//  Widget : Vue d'un Paragraphe
// ════════════════════════════════════════════════════════════

class _ParagraphView extends StatelessWidget {
  final Paragraph paragraph;
  final ScrollController scrollController;
  final Widget Function(ParagraphChoice) onChoice;
  final void Function(CombatData) onStartCombat;
  final void Function(CombatData, Enemy) onStartMultiCombat;

  const _ParagraphView({
    required this.paragraph,
    required this.scrollController,
    required this.onChoice,
    required this.onStartCombat,
    required this.onStartMultiCombat,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Numéro de §
                Text('§ ${paragraph.id}', style: const TextStyle(
                  fontFamily:'Cinzel', color:GraalTheme.textDim, fontSize:11, letterSpacing:2)),
                const SizedBox(height: 4),

                // Titre
                Text(paragraph.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),

                // Illustration
                if (paragraph.imageAsset != null)
                  _ParaImage(path: paragraph.imageAsset!),

                // Badge corruption
                if (paragraph.corruptionTier != null)
                  _CorruptBadge(tier: paragraph.corruptionTier!),

                const SizedBox(height: 8),

                // Texte markdown
                MarkdownBody(
                  data: paragraph.text,
                  styleSheet: MarkdownStyleSheet(
                    p: Theme.of(context).textTheme.bodyLarge,
                    strong: const TextStyle(
                      fontFamily:'Crimson Text', color:GraalTheme.amberLight,
                      fontWeight:FontWeight.bold, fontSize:18),
                    em: const TextStyle(
                      fontFamily:'Crimson Text', color:GraalTheme.textSecondary,
                      fontStyle:FontStyle.italic, fontSize:18),
                    blockquote: const TextStyle(
                      fontFamily:'Crimson Text', color:GraalTheme.magic, fontSize:16),
                    code: const TextStyle(
                      fontFamily:'Courier', color:GraalTheme.amber,
                      backgroundColor:GraalTheme.surfaceVariant, fontSize:14),
                  ),
                ),

                // Bouton de combat
                if (paragraph.combat != null) ...[
                  const SizedBox(height: 20),
                  _CombatBtn(combatData: paragraph.combat!, onStart: () => onStartCombat(paragraph.combat!)),
                ],

                // Séparateur + choix
                if (paragraph.choices.isNotEmpty) ...[
                  _OrnamentDivider(),
                  ...paragraph.choices.map(onChoice),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sous-widgets décoratifs ───────────────────────────────

class _ParaImage extends StatelessWidget {
  final String path;
  const _ParaImage({required this.path});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(border: Border.all(color: GraalTheme.divider)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.asset(path, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
    ),
  );
}

class _CorruptBadge extends StatelessWidget {
  final int tier;
  const _CorruptBadge({required this.tier});
  String get _cost => const {1:'100',2:'500',3:'1 000',4:'10 000'}[tier] ?? '?';
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1500),
      border: Border.all(color: GraalTheme.gold),
      borderRadius: BorderRadius.circular(4)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.monetization_on, color: GraalTheme.gold, size: 15),
      const SizedBox(width: 6),
      Text('Corruption : $_cost P.O.', style: const TextStyle(
        fontFamily:'Crimson Text', color:GraalTheme.gold, fontSize:14)),
    ]),
  );
}

class _CombatBtn extends StatelessWidget {
  final CombatData combatData;
  final VoidCallback onStart;
  const _CombatBtn({required this.combatData, required this.onStart});
  @override Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onStart,
      icon: const Icon(Icons.shield, size: 18),
      label: Text(combatData.multiCount > 1
          ? '⚔️  Combattre (${combatData.multiCount} ennemis)'
          : '⚔️  Engager le combat'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: const Color(0xFF2A0A0A),
        foregroundColor: GraalTheme.dangerLight,
        side: const BorderSide(color: GraalTheme.danger, width: 1)),
    ),
  );
}

class _OrnamentDivider extends StatelessWidget {
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(children: [
      Expanded(child: Container(height: 1, color: GraalTheme.divider)),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('⚔', style: TextStyle(color: GraalTheme.amber, fontSize: 16))),
      Expanded(child: Container(height: 1, color: GraalTheme.divider)),
    ]),
  );
}
