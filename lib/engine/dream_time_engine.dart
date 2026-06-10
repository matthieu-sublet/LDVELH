// ============================================================
//  engine/dream_time_engine.dart — Moteur du Temps du Rêve
// ============================================================
// Chaque section du Temps du Rêve (2 à 12) a ses propres règles.
// L'engine résout les rencontres et retourne un DreamResult.
// ============================================================

import 'dart:math';
import '../providers/game_providers.dart';

final _rng = Random();

class DreamResult {
  final bool survived;
  final int hpLost;
  final int hpGained;
  final String narrative;

  const DreamResult({
    required this.survived,
    this.hpLost = 0,
    this.hpGained = 0,
    required this.narrative,
  });
}

class DreamTimeEngine {
  // ── Résoudre une section du Temps du Rêve ────────────────

  static DreamResult resolve(int section) {
    switch (section) {
      case 2:  return _section2();
      case 3:  return _section3();
      case 4:  return _section4();
      case 5:  return _section5();
      case 6:  return _section5(); // identique à 5
      case 7:  return _section7();
      case 8:  return _section8();
      case 9:  return _section9();
      case 10: return _section10();
      case 11: return _section11();
      case 12: return _section12();
      default: return DreamResult(survived: true, narrative: 'Rêve sans danger.');
    }
  }

  // ── §2 : Ronge-Méninges ───────────────────────────────────
  // Créature qui frappe en premier, 15 PV, 5 dégâts/coup
  // Joueur sans armure → combat simplifié : on simule 3 rounds max
  static DreamResult _section2() {
    var log = <String>[];
    int enemyHp = 15;
    int playerDamage = 0;

    // L'ennemi frappe en premier
    for (int round = 1; round <= 10; round++) {
      // Attaque ennemie
      final er = roll2d6();
      if (er > 6) {
        final dmg = (er - 6) + 5;
        playerDamage += dmg;
        log.add('Ronde $round — Ronge-Méninges : $er → -$dmg PV (total perdu : $playerDamage)');
        if (playerDamage >= 999) break; // mort simulée
      } else {
        log.add('Ronde $round — Ronge-Méninges rate.');
      }
      // Attaque joueur (sans arme → seuil 6, 0 bonus)
      final pr = roll2d6();
      if (pr > 6) {
        final dmg = pr - 6;
        enemyHp -= dmg;
        log.add('           Vous : $pr → -$dmg PV ennemi (PV ennemi : $enemyHp)');
        if (enemyHp <= 0) break;
      }
    }

    final survived = enemyHp <= 0 || playerDamage < 9999;
    return DreamResult(
      survived: survived,
      hpLost: playerDamage,
      narrative: log.join('\n') + (survived ? '\n✅ Le Ronge-Méninges est vaincu !' : '\n☠️ Le Ronge-Méninges vous a eu.'),
    );
  }

  // ── §3 : Vampire (poursuite) ──────────────────────────────
  static DreamResult _section3() {
    final vampireForce = roll2d6();
    final playerForce = roll2d6();
    final caught = vampireForce >= playerForce + 5;
    return DreamResult(
      survived: !caught,
      hpLost: caught ? 9999 : 0,
      narrative: caught
          ? '🧛 Vampire force $vampireForce, vous $playerForce → différence ${vampireForce - playerForce} ≥ 5. Attrapé ! Mort.'
          : '🏃 Vampire force $vampireForce, vous $playerForce → vous lui échappez !',
    );
  }

  // ── §4 : Les deux calices ─────────────────────────────────
  static DreamResult _section4() {
    final roll = roll2d6();
    if (roll > 6) {
      return DreamResult(survived: true, hpLost: 0,
          narrative: '🍷 Vous lancez $roll → bon calice ! Vous buvez du vin, rien ne se passe.');
    } else {
      final poison = roll2d6();
      return DreamResult(survived: true, hpLost: poison,
          narrative: '☠️ Vous lancez $roll → poison ! Vous perdez $poison PV supplémentaires.');
    }
  }

  // ── §5/6 : Chute de la tour ───────────────────────────────
  static DreamResult _section5() {
    final fallRoll = roll2d6();
    if (fallRoll >= 6) {
      return DreamResult(survived: true, hpLost: 0,
          narrative: '🏰 Vous lancez $fallRoll → vous descendez sans tomber !');
    }
    // Chute !
    final landRoll = roll2d6();
    if (landRoll >= 6) {
      return DreamResult(survived: true, hpLost: 0,
          narrative: '💦 Vous tomber mais $landRoll → dans les douves ! Indemne.');
    }
    // Sol → -10 PV
    final swimRoll = roll2d6();
    if (swimRoll < 6) {
      return DreamResult(survived: false, hpLost: 9999,
          narrative: '💀 Vous tombez au sol ($landRoll) et ne savez pas nager ($swimRoll). Mort.');
    }
    return DreamResult(survived: true, hpLost: 10,
        narrative: '🌊 Vous tombez au sol (-10 PV), mais survivez.');
  }

  // ── §7 : Abeilles ou Céleri ───────────────────────────────
  static DreamResult _section7() {
    // 50/50 : abeilles ou céleri
    if (_rng.nextBool()) {
      final bees = roll1d6();
      return DreamResult(survived: true, hpLost: bees,
          narrative: '🐝 Essaim d\'abeilles ! $bees piqûres → -$bees PV.');
    } else {
      final goat = roll1d6();
      final dmg = goat < 6 ? 5 : 0;
      return DreamResult(survived: true, hpLost: dmg,
          narrative: dmg > 0
              ? '🥬 Transformé en céleri… La chèvre vous mange ($goat < 6) → -$dmg PV.'
              : '🥬 Transformé en céleri… La chèvre préfère les carottes ($goat ≥ 6). Indemne !');
    }
  }

  // ── §8 : Chevalier Noir ───────────────────────────────────
  // Armure joueur 5, arme +12. Chevalier armure 6, lance +10.
  static DreamResult _section8() {
    // Initiative
    final initRoll = roll2d6();
    bool playerFirst = initRoll >= 7;
    var log = <String>['⚔️ Initiative : $initRoll → ${playerFirst ? "vous" : "Chevalier"} en premier.'];

    int knightHp = 25;
    int playerDamage = 0;
    int knightArmor = 6;
    int playerArmor = 5;

    for (int round = 1; round <= 12; round++) {
      if (playerFirst) {
        // Joueur frappe
        final pr = roll2d6();
        if (pr > 6) {
          int dmg = max(0, (pr - 6) + 12 - knightArmor);
          knightArmor = max(0, knightArmor - ((pr - 6) + 12));
          if (knightArmor < 0) { dmg = -knightArmor; knightArmor = 0; }
          knightHp -= dmg;
          log.add('Ronde $round — Vous : $pr → $dmg dégâts. Chevalier : $knightHp PV');
          if (knightHp <= 0) break;
        }
      }
      // Chevalier frappe
      final kr = roll2d6();
      if (kr > 6) {
        int dmg = max(0, (kr - 6) + 10 - playerArmor);
        playerArmor = max(0, playerArmor - ((kr - 6) + 10));
        if (playerArmor < 0) { dmg = -playerArmor; playerArmor = 0; }
        playerDamage += dmg;
        log.add('         Chevalier : $kr → $dmg dégâts. Vous perdez $playerDamage PV au total.');
      }
      if (!playerFirst) {
        final pr = roll2d6();
        if (pr > 6) {
          int dmg = max(0, (pr - 6) + 12 - knightArmor);
          knightHp -= dmg;
          log.add('         Vous (riposte) : $pr → $dmg dégâts. Chevalier : $knightHp PV');
          if (knightHp <= 0) break;
        }
      }
    }

    final won = knightHp <= 0;
    return DreamResult(
      survived: won,
      hpLost: won ? playerDamage : 9999,
      narrative: log.join('\n') + (won ? '\n✅ Chevalier vaincu !' : '\n☠️ Le Chevalier Noir vous a tué.'),
    );
  }

  // ── §9 : Monstre du Sommeil + Coffrets ────────────────────
  static DreamResult _section9() {
    final coffret = roll1d6();
    if (coffret <= 3) {
      return DreamResult(survived: true, hpLost: 0,
          narrative: '🗡️ Coffret $coffret → dague magique ! Le Monstre du Sommeil est tué instantanément.');
    } else {
      return DreamResult(survived: true, hpLost: 0,
          narrative: '😴 Coffret $coffret → gaz soporifique. Vous vous rendormez dans le Temps du Rêve…',
          hpGained: 0);
      // Le joueur relance dans le Temps du Rêve — géré côté UI
    }
  }

  // ── §10 : L'Ogre et les 7 Flèches ────────────────────────
  static DreamResult _section10() {
    var log = <String>[];
    int ogreHp = 40;
    int playerDamage = 0;

    // 7 flèches
    for (int i = 1; i <= 7; i++) {
      final roll = roll2d6();
      if (roll > 6) {
        ogreHp -= 10;
        log.add('Flèche $i : $roll → touché ! Ogre : $ogreHp PV');
        if (ogreHp <= 0) break;
      } else {
        log.add('Flèche $i : $roll → manqué.');
      }
    }
    // Si ogre vivant → combat mains nues (1 round, 15 dégâts si ogre touche)
    if (ogreHp > 0) {
      final finalRoll = roll2d6();
      if (finalRoll > 6) {
        ogreHp -= (finalRoll - 6);
        log.add('Corps-à-corps : $finalRoll → ${finalRoll-6} dégâts. Ogre : $ogreHp PV');
      }
      if (ogreHp > 0) {
        playerDamage += 15;
        log.add('⚠️ L\'Ogre vous écrase avec sa massue : -15 PV.');
      }
    }

    return DreamResult(
      survived: ogreHp <= 0 || playerDamage < 9999,
      hpLost: playerDamage,
      narrative: log.join('\n') + (ogreHp <= 0 ? '\n✅ L\'Ogre est mort !' : '\n⚠️ L\'Ogre est encore debout…'),
    );
  }

  // ── §11 : Oubliette ───────────────────────────────────────
  static DreamResult _section11() {
    final days = roll1d6();
    return DreamResult(
      survived: true,
      hpLost: days,
      narrative: '🏛️ Emprisonné $days jour(s) dans l\'oubliette du Roi Arthur → -$days PV.',
    );
  }

  // ── §12 : Duel de magie ───────────────────────────────────
  static DreamResult _section12() {
    final sorcerer = roll1d6();
    final player = roll1d6();
    int hpLost = 0;
    String result;
    if (player > sorcerer) {
      result = '✨ Vous gagnez le duel ! ($player vs $sorcerer). Les PV du Sorcier sont divisés par 2.';
    } else {
      // Vos PV divisés par 2 → on retourne une perte relative
      hpLost = -1; // Signale "diviser PV par 2" → traité côté UI
      result = '💀 Le Sorcier gagne ($sorcerer vs $player). Vos PV sont réduits de moitié.';
    }
    return DreamResult(survived: true, hpLost: hpLost, narrative: result);
  }
}
