import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';
import '../providers/game_providers.dart';

class CombatOverlay extends ConsumerWidget {
  final void Function(bool won, String targetParagraph) onCombatEnd;
  const CombatOverlay({super.key, required this.onCombatEnd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combat = ref.watch(combatProvider);
    final player = ref.watch(playerStateProvider);
    final enemy = combat.enemy;

    if (combat.phase == CombatPhase.playerWon && combat.winParagraphId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showDialog(
          context: context, barrierDismissible: false,
          builder: (_) => _VictoryDialog(
            enemyName: enemy?.name ?? 'l\'ennemi',
            onContinue: () {
              Navigator.of(context).pop();
              onCombatEnd(true, combat.winParagraphId!);
            },
          ),
        );
      });
    }

    if (combat.phase == CombatPhase.playerDied && combat.deathParagraphId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showDialog(
          context: context, barrierDismissible: false,
          builder: (_) => _DeathDialog(
            onContinue: () {
              Navigator.of(context).pop();
              onCombatEnd(false, combat.deathParagraphId!);
            },
          ),
        );
      });
    }

    if (enemy == null) return const SizedBox.shrink();

    return Material(
      color: Colors.black.withValues(alpha: 0.90),
      child: SafeArea(
        child: Column(children: [
          _EnemyHeader(enemy: enemy),
          _PlayerHpBar(currentHp: player.currentHp, maxHp: player.maxHp),
          Expanded(child: _CombatLog(log: combat.log)),
          if (combat.phase == CombatPhase.playerTurn)
            _PlayerActions(
              player: player,
              onAttack: () => ref.read(combatProvider.notifier).playerAttacks(),
              onMagic: (id) => ref.read(combatProvider.notifier).useMagicFinger(id),
              onFriendlyReaction: () {
                final result = ref.read(combatProvider.notifier).tryFriendlyReaction();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result)));
              },
            ),
          if (combat.phase == CombatPhase.enemyTurn)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('⌛ L\'ennemi attaque...',
                style: TextStyle(fontFamily:'Cinzel', color:GraalTheme.danger, fontSize:16)),
            ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _EnemyHeader extends StatelessWidget {
  final EnemyData enemy;
  const _EnemyHeader({required this.enemy});

  @override
  Widget build(BuildContext context) {
    final ratio = (enemy.currentHp / enemy.lifePoints).clamp(0.0, 1.0);
    final col = ratio > .5 ? GraalTheme.danger : ratio > .25 ? GraalTheme.amber : GraalTheme.amberLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GraalTheme.divider))),
      child: Column(children: [
        Text('⚔️  ${enemy.name}', style: const TextStyle(
          fontFamily:'Cinzel', color:GraalTheme.amberLight, fontSize:20, fontWeight:FontWeight.bold)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.favorite, color: GraalTheme.danger, size: 16),
          const SizedBox(width: 6),
          Text('${enemy.currentHp} / ${enemy.lifePoints} PV',
            style: TextStyle(fontFamily:'Crimson Text', color:col, fontSize:16, fontWeight:FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio, backgroundColor: GraalTheme.surfaceVariant,
            color: col, minHeight: 6),
        ),
      ]),
    );
  }
}

class _PlayerHpBar extends StatelessWidget {
  final int currentHp, maxHp;
  const _PlayerHpBar({required this.currentHp, required this.maxHp});
  @override
  Widget build(BuildContext context) {
    final ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final col = ratio > .5 ? GraalTheme.success : ratio > .25 ? GraalTheme.amber : GraalTheme.dangerLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Text('PIP ', style: TextStyle(fontFamily:'Cinzel', color:GraalTheme.textSecondary, fontSize:11)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: ratio,
            backgroundColor: GraalTheme.surfaceVariant, color: col, minHeight: 8),
        )),
        const SizedBox(width: 8),
        Text('$currentHp/$maxHp', style: TextStyle(
          fontFamily:'Crimson Text', color:col, fontSize:14, fontWeight:FontWeight.bold)),
      ]),
    );
  }
}

class _CombatLog extends StatefulWidget {
  final List<String> log;
  const _CombatLog({required this.log});
  @override State<_CombatLog> createState() => _CombatLogState();
}
class _CombatLogState extends State<_CombatLog> {
  final _sc = ScrollController();
  @override void didUpdateWidget(_CombatLog old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: GraalTheme.surface,
      border: Border.all(color: GraalTheme.divider), borderRadius: BorderRadius.circular(4)),
    child: ListView.builder(
      controller: _sc, itemCount: widget.log.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(widget.log[i], style: const TextStyle(
          fontFamily:'Crimson Text', color:GraalTheme.textPrimary, fontSize:14, height:1.4)),
      )),
  );
}

class _PlayerActions extends StatelessWidget {
  final PlayerState player;
  final VoidCallback onAttack, onFriendlyReaction;
  final void Function(String) onMagic;
  const _PlayerActions({required this.player, required this.onAttack,
    required this.onFriendlyReaction, required this.onMagic});

  @override
  Widget build(BuildContext context) {
    final mr = player.inventory.firstWhere((i) => i.id == 'fire_finger_right',
      orElse: () => InventoryItem(id:'_', name:'', type:ItemType.magic, description:''));
    final ml = player.inventory.firstWhere((i) => i.id == 'fire_finger_left',
      orElse: () => InventoryItem(id:'_', name:'', type:ItemType.magic, description:''));
    final weaponName = player.inventory
        .where((i) => i.type == ItemType.weapon)
        .map((i) => i.name)
        .firstOrNull ?? 'poings';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: [
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: onAttack,
          icon: const Icon(Icons.gavel, size: 18),
          label: Text('⚔️  Attaquer avec $weaponName'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF1A0E00),
            foregroundColor: GraalTheme.amber,
            side: const BorderSide(color: GraalTheme.amber)),
        )),
        const SizedBox(height: 6),
        Row(children: [
          if (mr.id != '_' && mr.usesRemaining > 0)
            Expanded(child: _SmallBtn('✨ D.Feu D (${mr.usesRemaining})',
              GraalTheme.magic, () => onMagic('fire_finger_right'))),
          if (mr.id != '_' && mr.usesRemaining > 0 && ml.id != '_' && ml.usesRemaining > 0)
            const SizedBox(width: 6),
          if (ml.id != '_' && ml.usesRemaining > 0)
            Expanded(child: _SmallBtn('✨ D.Feu G (${ml.usesRemaining})',
              GraalTheme.magic, () => onMagic('fire_finger_left'))),
        ]),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: OutlinedButton(
          onPressed: onFriendlyReaction,
          style: OutlinedButton.styleFrom(
            foregroundColor: GraalTheme.success,
            side: const BorderSide(color: GraalTheme.success),
            padding: const EdgeInsets.symmetric(vertical: 10)),
          child: const Text('🤝 Réaction Amicale'),
        )),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _SmallBtn(this.label, this.color, this.onTap);
  @override Widget build(BuildContext ctx) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: color, side: BorderSide(color: color),
      padding: const EdgeInsets.symmetric(vertical: 10)),
    child: Text(label, style: TextStyle(fontFamily:'Crimson Text', color:color, fontSize:12)));
}

class _VictoryDialog extends StatelessWidget {
  final String enemyName; final VoidCallback onContinue;
  const _VictoryDialog({required this.enemyName, required this.onContinue});
  @override Widget build(BuildContext context) => AlertDialog(
    backgroundColor: GraalTheme.surfaceVariant,
    title: const Text('🏆 Victoire !', style: TextStyle(fontFamily:'Cinzel', color:GraalTheme.amberLight, fontSize:22)),
    content: Text('Vous avez vaincu $enemyName !\n\n+1 Point d\'Expérience.',
      style: const TextStyle(fontFamily:'Crimson Text', color:GraalTheme.textPrimary, fontSize:17)),
    actions: [ElevatedButton(onPressed: onContinue, child: const Text('Continuer'))],
  );
}

class _DeathDialog extends StatelessWidget {
  final VoidCallback onContinue;
  const _DeathDialog({required this.onContinue});
  @override Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF1A0000),
    title: const Text('☠️  Vous êtes mort.', style: TextStyle(fontFamily:'Cinzel', color:GraalTheme.dangerLight, fontSize:22)),
    content: const Text('L\'aventure s\'arrête ici...\n\nVos ennemis vaincus restent morts lors de votre prochaine tentative.',
      style: TextStyle(fontFamily:'Crimson Text', color:GraalTheme.textPrimary, fontSize:17)),
    actions: [ElevatedButton(onPressed: onContinue,
      style: ElevatedButton.styleFrom(backgroundColor: GraalTheme.danger, foregroundColor: Colors.white),
      child: const Text('Recommencer'))],
  );
}
