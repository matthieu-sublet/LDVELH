import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';
import '../providers/persistence_service.dart';
import '../widgets/character_drawer.dart';
import '../widgets/combat_overlay.dart';
import '../widgets/hp_setup_screen.dart';
import '../widgets/choice_button.dart';

class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({super.key});
  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late AnimationController _fade;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeIn);
    _fade.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSave());
  }

  @override
  void dispose() { _scroll.dispose(); _fade.dispose(); super.dispose(); }

  void _loadSave() {
    final svc = ref.read(persistenceServiceProvider);
    if (svc == null || !svc.hasSave) return;
    final saved = svc.loadState();
    if (saved != null && saved.maxHp > 0) {
      ref.read(playerStateProvider.notifier).restoreFrom(saved);
    }
  }

  Future<void> _transition(VoidCallback action) async {
    await _fade.reverse();
    action();
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
    ref.read(persistenceServiceProvider)?.saveState(ref.read(playerStateProvider));
    await _fade.forward();
  }

  void _goToNextChapter() {
    _transition(() {
      ref.read(gameBookProvider).whenData((book) {
        ref.read(playerStateProvider.notifier).goToNextChapter(book);
      });
    });
  }

  void _goToParagraph(String paragraphId) {
    _transition(() {
      if (paragraphId == 'dream_time') {
        _openDreamTime();
        return;
      }
      // Mort → revenir au début du château
      if (paragraphId == '14') {
        ref.read(playerStateProvider.notifier).goToParagraph('14');
        return;
      }
      ref.read(playerStateProvider.notifier).goToParagraph(paragraphId);
    });
  }

  void _openDreamTime() async {
    _fade.forward();
    final survived = await Navigator.of(context).pushNamed('/dream');
    if (survived == false) {
      ref.read(playerStateProvider.notifier).goToParagraph('14');
    }
  }

  void _trySleep() async {
    final result = trySleep();
    if (result.dreamEncountered) {
      _showSnack('😴 Résultat ${result.roll} — Temps du Rêve...', GraalTheme.magic);
      await Future.delayed(const Duration(milliseconds: 600));
      _openDreamTime();
    } else {
      ref.read(playerStateProvider.notifier).heal(result.healedHp);
      _showSnack('💤 Sommeil réparateur. +${result.healedHp} PV.', GraalTheme.success);
    }
  }

  void _usePotion() {
    final player = ref.read(playerStateProvider);
    final p = player.inventory.firstWhere(
      (i) => i.id == 'healing_potion',
      orElse: () => InventoryItem(id:'_', name:'', type:ItemType.consumable, description:''),
    );
    if (p.id == '_' || p.usesRemaining <= 0) {
      _showSnack('Aucune Potion disponible.', GraalTheme.danger); return;
    }
    ref.read(playerStateProvider.notifier).useConsumable('healing_potion');
    _showSnack('🧪 Potion prise ! (${p.usesRemaining - 1} doses restantes)', GraalTheme.success);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerStateProvider);
    final bookAsync = ref.watch(gameBookProvider);
    final combat = ref.watch(combatProvider);

    if (player.maxHp == 0) {
      return HpSetupScreen(onConfirm: (hp, inv) {
        ref.read(playerStateProvider.notifier).setStartingHp(hp);
        for (final item in inv) ref.read(playerStateProvider.notifier).addItem(item);
        ref.read(playerStateProvider.notifier).goToChapter('ch_merlin');
      });
    }

    return Scaffold(
      backgroundColor: GraalTheme.background,
      drawer: const CharacterDrawer(),
      appBar: _buildAppBar(player),
      body: Stack(children: [
        bookAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: GraalTheme.amber)),
          error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: GraalTheme.danger))),
          data: (book) {
            final chapter = book.chapterById(player.currentChapterId);
            if (chapter == null) {
              return Center(child: Text('Chapitre "${player.currentChapterId}" introuvable.',
                style: const TextStyle(color: GraalTheme.danger)));
            }
            return FadeTransition(
              opacity: _fadeAnim,
              child: chapter.type == ChapterType.narration
                  ? _NarrationView(
                      chapter: chapter,
                      scrollController: _scroll,
                      onContinue: _goToNextChapter,
                    )
                  : _buildGameView(chapter, player, book),
            );
          },
        ),
        if (combat.phase != CombatPhase.idle)
          CombatOverlay(onCombatEnd: (won, targetId) {
            ref.read(combatProvider.notifier).reset();
            _goToParagraph(targetId);
          }),
      ]),
    );
  }

  Widget _buildGameView(GameChapter chapter, PlayerState player, GameBook book) {
    final pid = player.currentParagraphId ?? chapter.paragrapheDepart;
    GameParagraph? para;
    try {
      para = pid != null ? chapter.paragraphes.firstWhere((p) => p.id == pid) : null;
    } catch (_) { para = null; }

    if (para == null) {
      return Center(child: Text('Paragraphe "$pid" introuvable.',
        style: const TextStyle(color: GraalTheme.danger)));
    }

    return _ParagraphView(
      paragraph: para,
      scrollController: _scroll,
      player: player,
      onChoice: (choice) {
        // Fin du château → triomphe
        if (choice.nextId == 'triomphe' || (para!.id == '135')) {
          _transition(() => ref.read(playerStateProvider.notifier).goToChapter('ch_triomphe'));
          return;
        }
        _goToParagraph(choice.nextId);
      },
      onStartCombat: () {
        final enemy = para!.enemy;
        if (enemy == null) return;
        ref.read(combatProvider.notifier).startCombat(
          enemy,
          playerFirst: true,
          onWin: _nextParagraphAfterCombat(para, chapter),
          onDeath: '14',
        );
      },
    );
  }

  String _nextParagraphAfterCombat(GameParagraph para, GameChapter chapter) {
    if (para.choices.isNotEmpty) return para.choices.first.nextId;
    final idx = chapter.paragraphes.indexWhere((p) => p.id == para.id);
    if (idx >= 0 && idx + 1 < chapter.paragraphes.length) {
      return chapter.paragraphes[idx + 1].id;
    }
    return para.id;
  }

  AppBar _buildAppBar(PlayerState player) {
    final ratio = player.maxHp > 0 ? player.currentHp / player.maxHp : 0.0;
    final hpColor = ratio > .5 ? GraalTheme.success : ratio > .25 ? GraalTheme.amber : GraalTheme.dangerLight;
    return AppBar(
      backgroundColor: GraalTheme.background,
      leading: Builder(builder: (ctx) => IconButton(
        icon: const Icon(Icons.menu_book_rounded, color: GraalTheme.amber),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
      )),
      title: const Text('Le Château des Ténèbres',
        style: TextStyle(fontFamily: 'Cinzel', color: GraalTheme.amber, fontSize: 15, letterSpacing: 1)),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(children: [
            Icon(Icons.favorite, color: hpColor, size: 14),
            const SizedBox(width: 3),
            Text('${player.currentHp}/${player.maxHp}',
              style: TextStyle(fontFamily: 'Crimson Text', color: hpColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: GraalTheme.amber),
          color: GraalTheme.surfaceVariant,
          onSelected: (v) { if (v == 'sleep') _trySleep(); if (v == 'potion') _usePotion(); },
          itemBuilder: (_) => const [
            PopupMenuItem(value:'sleep', child: Text('💤 Dormir', style: TextStyle(color:GraalTheme.textPrimary))),
            PopupMenuItem(value:'potion', child: Text('🧪 Potion', style: TextStyle(color:GraalTheme.textPrimary))),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Vue Narration
// ══════════════════════════════════════════════════════════

class _NarrationView extends StatelessWidget {
  final GameChapter chapter;
  final ScrollController scrollController;
  final VoidCallback onContinue;
  const _NarrationView({required this.chapter, required this.scrollController, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(chapter.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            MarkdownBody(
              data: chapter.contenu ?? '',
              styleSheet: _mdStyle(context),
            ),
            const SizedBox(height: 32),
            if (chapter.suivant != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Continuer →'),
                ),
              ),
          ]),
        ),
      )],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Vue Paragraphe de jeu
// ══════════════════════════════════════════════════════════

class _ParagraphView extends StatelessWidget {
  final GameParagraph paragraph;
  final ScrollController scrollController;
  final PlayerState player;
  final void Function(ParagraphChoice) onChoice;
  final VoidCallback onStartCombat;
  const _ParagraphView({
    required this.paragraph, required this.scrollController,
    required this.player, required this.onChoice, required this.onStartCombat,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('§ ${paragraph.id}', style: const TextStyle(
              fontFamily:'Cinzel', color:GraalTheme.textDim, fontSize:11, letterSpacing:2)),
            const SizedBox(height: 4),
            Text(paragraph.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            if (paragraph.corruptionTier != null)
              _CorruptBadge(tier: paragraph.corruptionTier!),
            const SizedBox(height: 8),
            MarkdownBody(data: paragraph.text, styleSheet: _mdStyle(context)),
            if (paragraph.enemy != null) ...[
              const SizedBox(height: 16),
              _EnemyCard(enemy: paragraph.enemy!, onFight: onStartCombat),
            ],
            if (paragraph.choices.isNotEmpty) ...[
              _OrnamentDivider(),
              ...paragraph.choices.map((c) {
                final itemOk = c.requiresItem == null || player.hasItem(c.requiresItem!);
                final goldOk = c.requiresGold == null || player.hasGold(c.requiresGold!);
                final ok = itemOk && goldOk;
                if (!ok && c.hiddenIfMissing) return const SizedBox.shrink();
                String label = c.text;
                if (!itemOk) label += '\n  [Objet requis]';
                if (!goldOk) label += '\n  [Or insuffisant]';
                return ChoiceButton(label: label, enabled: ok, onTap: ok ? () => onChoice(c) : null);
              }),
            ],
            const SizedBox(height: 20),
          ]),
        ),
      )],
    );
  }
}

// ── Sous-widgets ──────────────────────────────────────────

class _EnemyCard extends StatelessWidget {
  final EnemyData enemy;
  final VoidCallback onFight;
  const _EnemyCard({required this.enemy, required this.onFight});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF2A0A0A),
      border: Border.all(color: GraalTheme.danger),
      borderRadius: BorderRadius.circular(4)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('⚔️ ${enemy.name}', style: const TextStyle(
        fontFamily:'Cinzel', color:GraalTheme.dangerLight, fontSize:16, fontWeight:FontWeight.bold)),
      const SizedBox(height: 4),
      Text('${enemy.lifePoints} PV${enemy.extraDamage > 0 ? " · +${enemy.extraDamage} dégâts" : ""}',
        style: const TextStyle(fontFamily:'Crimson Text', color:GraalTheme.textSecondary, fontSize:14)),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: onFight,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A0A0A),
          foregroundColor: GraalTheme.dangerLight,
          side: const BorderSide(color: GraalTheme.danger)),
        child: const Text('⚔️  Combattre'),
      )),
    ]),
  );
}

class _CorruptBadge extends StatelessWidget {
  final int tier;
  const _CorruptBadge({required this.tier});
  String get _cost => const {1:'100',2:'500',3:'1 000',4:'10 000'}[tier] ?? '?';
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1500), border: Border.all(color: GraalTheme.gold),
      borderRadius: BorderRadius.circular(4)),
    child: Text('💰 Corruption : $_cost P.O.',
      style: const TextStyle(fontFamily:'Crimson Text', color:GraalTheme.gold, fontSize:13)),
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

MarkdownStyleSheet _mdStyle(BuildContext context) => MarkdownStyleSheet(
  p: Theme.of(context).textTheme.bodyLarge,
  strong: const TextStyle(fontFamily:'Crimson Text', color:GraalTheme.amberLight, fontWeight:FontWeight.bold, fontSize:18),
  em: const TextStyle(fontFamily:'Crimson Text', color:GraalTheme.textSecondary, fontStyle:FontStyle.italic, fontSize:18),
);
