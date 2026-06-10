#!/usr/bin/env python3
"""
parse_graal.py — Convertisseur Markdown → JSON pour Le Château des Ténèbres
Produit : assets/data/game_structure.json  (paragraphes + ennemis + config)

Usage :
    python3 parse_graal.py source.md
"""

import re, json, sys, textwrap
from pathlib import Path

# ══════════════════════════════════════════════════════════════
#  TABLES STATIQUES (ennemis, config)
# ══════════════════════════════════════════════════════════════

ENEMIES = {
    "wolf": {
        "id": "wolf", "name": "Loup", "max_hp": 20,
        "attack_threshold": 6, "bonus_damage": 3, "armor_points": 0,
        "dragon_coat_bypassed": True, "strikes_first": False,
        "image": "assets/images/enemies/wolf.png", "special_notes": "Le pourpoint en peau de dragon ne protège pas (attaque les zones non couvertes)."
    },
    "boar": {
        "id": "boar", "name": "Sanglier", "max_hp": 25,
        "attack_threshold": 6, "bonus_damage": 4, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/boar.png", "special_notes": ""
    },
    "vegetable_monster": {
        "id": "vegetable_monster", "name": "Monstre Végétal", "max_hp": 35,
        "attack_threshold": 5, "bonus_damage": 4, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": True,
        "image": "assets/images/enemies/vegetal.png",
        "special_notes": "Frappe en premier (joueur surpris en train de fouiller)."
    },
    "skeleton": {
        "id": "skeleton", "name": "Squelette", "max_hp": 15,
        "attack_threshold": 6, "bonus_damage": 2, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/skeleton.png", "special_notes": ""
    },
    "mastiff": {
        "id": "mastiff", "name": "Molosse", "max_hp": 20,
        "attack_threshold": 5, "bonus_damage": 3, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/mastiff.png", "special_notes": ""
    },
    "mastiff_boss": {
        "id": "mastiff_boss", "name": "Molosse d'Ansalom", "max_hp": 25,
        "attack_threshold": 6, "bonus_damage": 4, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/mastiff.png",
        "special_notes": "Garde le trône d'Ansalom."
    },
    "spider": {
        "id": "spider", "name": "Araignée Géante", "max_hp": 33,
        "attack_threshold": 4, "bonus_damage": 3, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/spider.png",
        "special_notes": "Venimeuse : 3 morsures → empoisonnement. Lancer 2d6 ≥ 6 pour survivre au venin."
    },
    "goblin": {
        "id": "goblin", "name": "Farfadet", "max_hp": 40,
        "attack_threshold": 6, "bonus_damage": 0, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/goblin.png",
        "special_notes": "Invisible dans l'obscurité magique."
    },
    "zombie": {
        "id": "zombie", "name": "Zombie", "max_hp": 20,
        "attack_threshold": 6, "bonus_damage": 0, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/zombie.png",
        "special_notes": "Ne peut être tué que sur un résultat de 9-12 aux dés (sinon assommé seulement)."
    },
    "guard": {
        "id": "guard", "name": "Garde", "max_hp": 15,
        "attack_threshold": 6, "bonus_damage": 2, "armor_points": 2,
        "dragon_coat_bypassed": False, "strikes_first": True,
        "image": "assets/images/enemies/guard.png",
        "special_notes": "Armure protège de 2 pts de dommage."
    },
    "guard_elite": {
        "id": "guard_elite", "name": "Garde d'élite", "max_hp": 20,
        "attack_threshold": 3, "bonus_damage": 2, "armor_points": 2,
        "dragon_coat_bypassed": False, "strikes_first": True,
        "image": "assets/images/enemies/guard.png",
        "special_notes": "Très rapide : frappe sur 3+. Armure 2 pts."
    },
    "demon_invisible": {
        "id": "demon_invisible", "name": "Démon Invisible", "max_hp": 40,
        "attack_threshold": 8, "bonus_damage": 5, "armor_points": 4,
        "dragon_coat_bypassed": False, "strikes_first": True,
        "image": "assets/images/enemies/demon.png",
        "special_notes": "Invisible. Frappe en premier. Armure naturelle 4 pts. Joueur doit faire 8+ pour toucher."
    },
    "ansalom_dogs": {
        "id": "ansalom_dogs", "name": "Molosses d'Ansalom (×2)", "max_hp": 25,
        "attack_threshold": 6, "bonus_damage": 4, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/mastiff.png",
        "special_notes": "Combattus en séquence. Ansalom n'attaque pas avant leur mort."
    },
    "ansalom": {
        "id": "ansalom", "name": "Ansalom le Sorcier", "max_hp": 150,
        "attack_threshold": 5, "bonus_damage": 0, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/ansalom.png",
        "special_notes": "Boss final. 10 Doigts de Feu (lancé 2d6 ≥ 5 pour toucher, 10 dégâts chacun). 150 PV."
    },
    # Temps du Rêve
    "dream_nibbler": {
        "id": "dream_nibbler", "name": "Ronge-Méninges", "max_hp": 15,
        "attack_threshold": 6, "bonus_damage": 5, "armor_points": 0,
        "dragon_coat_bypassed": True, "strikes_first": True,
        "image": "assets/images/enemies/dream_nibbler.png",
        "special_notes": "Rêve §2. Sans armure ni arme. Frappe en premier, 5 dégâts/passage."
    },
    "black_knight_dream": {
        "id": "black_knight_dream", "name": "Chevalier Noir (Rêve)", "max_hp": 25,
        "attack_threshold": 6, "bonus_damage": 10, "armor_points": 6,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/black_knight.png",
        "special_notes": "Rêve §8. Lance magique : +10 dégâts. Armure 6 pts. Lance du joueur : +12 dégâts. Initiative par 2d6 (7+ = joueur)."
    },
    "sleep_monster": {
        "id": "sleep_monster", "name": "Monstre du Sommeil", "max_hp": 30,
        "attack_threshold": 6, "bonus_damage": 5, "armor_points": 0,
        "dragon_coat_bypassed": True, "strikes_first": True,
        "image": "assets/images/enemies/sleep_monster.png",
        "special_notes": "Rêve §9. Sans armure ni arme standard."
    },
    "old_man_traitor": {
        "id": "old_man_traitor", "name": "Vieillard (traître)", "max_hp": 25,
        "attack_threshold": 6, "bonus_damage": 2, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": True,
        "image": "assets/images/enemies/old_man.png",
        "special_notes": "Sort une dague cachée par surprise (frappe en premier, 2 dégâts)."
    },
    "nosferax": {
        "id": "nosferax", "name": "Nosfèrax le Vampire", "max_hp": 30,
        "attack_threshold": 6, "bonus_damage": 5, "armor_points": 0,
        "dragon_coat_bypassed": False, "strikes_first": False,
        "image": "assets/images/enemies/vampire.png",
        "special_notes": "Fuit l'ail. Si joueur a de l'ail → victoire automatique (§132)."
    }
}

GAME_CONFIG = {
    "starting_paragraph": "intro",
    "death_paragraph": "14",
    "starting_inventory": [
        {"id":"ej","name":"Excalibur Junior (E.J.)","type":"weapon","description":"Épée magique de Merlin. Parle parfois. Seuil d'attaque : 4. +5 dégâts.","attack_threshold_override":4,"bonus_damage":5,"uses_remaining":0,"uses_total":0},
        {"id":"dagger","name":"Dague","type":"weapon","description":"+2 dégâts supplémentaires.","attack_threshold_override":None,"bonus_damage":2,"uses_remaining":0,"uses_total":0},
        {"id":"dragon_coat","name":"Pourpoint en peau de dragon","type":"armor","description":"Réduit les dégâts reçus de 5 points. Contourné par le Loup.","damage_reduction":5,"uses_remaining":0,"uses_total":0},
        {"id":"healing_potion","name":"Potion Curative (3 fioles × 6 doses)","type":"consumable","description":"Récupère 2d6 PV par dose. Goût horrible.","uses_remaining":18,"uses_total":18,"effect":"heal_2d6"},
        {"id":"fire_finger_right","name":"Doigt de Feu 1 (index droit)","type":"magic","description":"Éclair infaillible. 10 dégâts. 5 charges.","uses_remaining":5,"uses_total":5,"effect":"damage_10_no_roll"},
        {"id":"fire_finger_left","name":"Doigt de Feu 2 (index gauche)","type":"magic","description":"Éclair infaillible. 10 dégâts. 5 charges.","uses_remaining":5,"uses_total":5,"effect":"damage_10_no_roll"},
        {"id":"sandwich","name":"Sandwich au rosbif","type":"quest","description":"Utile pour amadouer les loups.","uses_remaining":1,"uses_total":1}
    ],
    "starting_gold": {"gold_pieces":0,"silver_pieces":0,"gems":0},
    "combat_rules": {"base_attack_threshold":6,"note":"2d6 > seuil = touché. Excès = dégâts."},
    "sleep_rules": {"roll_1d6":True,"dream_on":[1,2,3,4],"heal_on":[5,6],"heal_roll":"2d6"},
    "experience_rules": {"xp_per_combat":1,"xp_per_enigma":1,"xp_for_perm_hp":20,"max_storable":10},
    "corruption_costs": {"1":100,"2":500,"3":1000,"4":10000},
    "friendly_reaction": {"player_rolls":3,"enemy_rolls":1,"condition":"best_player < enemy_roll"},
    "dream_time_roll": "2d6",
    "hp_init": {"rolls":3,"formula":"2d6 * 4","min":8,"max":48}
}

# ══════════════════════════════════════════════════════════════
#  PARAGRAPHES MANUELS (intro + fins spéciales)
# ══════════════════════════════════════════════════════════════

MANUAL_PARAGRAPHS = {
    "intro": {
        "id": "intro",
        "title": "Le Sortilège de Merlin",
        "text": (
            "Un vieux magicien vous parle depuis les pages d'un livre ancien. Il s'appelle **Merlin**.\n\n"
            "Il vous explique que votre esprit va être transporté dans le passé, dans le corps d'un jeune garçon nommé **Pip**. "
            "La reine **Guenièvre** a été enlevée par le sorcier **Ansalom** et cachée dans son Château des Ténèbres.\n\n"
            "Merlin vous remet votre équipement de départ :\n\n"
            "- **Excalibur Junior (E.J.)** — épée magique (seuil 4, +5 dégâts)\n"
            "- **Pourpoint en peau de dragon** — réduit les dégâts reçus de 5\n"
            "- **3 fioles de Potion Curative** (6 doses chacune, 2d6 PV)\n"
            "- **Doigt de Feu** × 10 charges (5 par main, 10 dégâts garantis)\n\n"
            "*« Voilà. Maintenant, il faut s'occuper de cette affaire. Du moins... il faut que tu t'en occupes, toi. Moi, je n'ai pas le temps. »*"
        ),
        "image": "assets/images/paragraphs/merlin.png",
        "combat": None, "loot": [], "corruption_tier": None,
        "choices": [{"text":"Partir vers la forêt — commencer l'aventure","target_paragraph":"8","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "victory": {
        "id": "victory",
        "title": "Le Triomphe de Pip",
        "text": (
            "Vous vous tenez, triomphant, dans la salle du trône d'Ansalom.\n\n"
            "Derrière le trône, une porte secrète révèle un escalier descendant vers les geôles. "
            "Vous y trouvez la **reine Guenièvre**, belle et courageuse malgré sa captivité.\n\n"
            "*— Vous êtes venu me sauver ! dit-elle. Merlin m'avait prédit que quelqu'un viendrait.*\n\n"
            "Vous la guidez hors du château. Dans la forêt, Merlin vous attend, assis sur une souche.\n\n"
            "*« Ton aventure est finie. Terminée. Achevée. Couronnée de succès. »*\n\n"
            "Il sourit. *« Avalon a besoin d'êtres d'élite comme toi. Je reviendrai te chercher pour de nouvelles aventures... »*\n\n"
            "**🏆 Félicitations ! Vous avez sauvé la Reine.**"
        ),
        "image": "assets/images/paragraphs/victory.png",
        "is_victory_paragraph": True,
        "combat": None, "loot": [], "corruption_tier": None,
        "choices": [{"text":"Recommencer une nouvelle aventure","target_paragraph":"intro","requires_item":None,"requires_gold":None,"hidden_if_missing":False,"resets_game":True}]
    },
    "dream_time": {
        "id": "dream_time",
        "title": "Le Temps du Rêve",
        "text": (
            "Vous sombrez dans le sommeil... et vous entrez dans le **Temps du Rêve**.\n\n"
            "**Règles spéciales :**\n"
            "- Vous y entrez sans armure ni protection\n"
            "- Sans magie ni arme (sauf celles obtenues dans le Rêve)\n"
            "- Tout PV perdu est déduit de votre total réel\n"
            "- Si vous mourez dans le Rêve → mort définitive (§ 14)\n\n"
            "Lancez 2d6 pour savoir quelle aventure vous attend dans le Rêve..."
        ),
        "image": "assets/images/paragraphs/dream.png",
        "combat": None, "loot": [], "corruption_tier": None,
        "is_dream_entry": True,
        "choices": [
            {"text":"2 — Le Ronge-Méninges","target_paragraph":"dream_2","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"3 — Le Vampire (course-poursuite)","target_paragraph":"dream_3","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"4 — Les deux calices (vin ou poison ?)","target_paragraph":"dream_4","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"5 — La chute de la tour","target_paragraph":"dream_5","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"6 — La chute de la tour (suite)","target_paragraph":"dream_5","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"7 — L'essaim d'abeilles / Le céleri","target_paragraph":"dream_7","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"8 — Le Chevalier Noir","target_paragraph":"dream_8","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"9 — Le Monstre du Sommeil","target_paragraph":"dream_9","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"10 — L'Ogre et les flèches","target_paragraph":"dream_10","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"11 — L'oubliette du Roi Arthur","target_paragraph":"dream_11","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"12 — La bataille magique","target_paragraph":"dream_12","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
        ]
    },
    "dream_2": {
        "id":"dream_2","title":"Rêve : Le Ronge-Méninges",
        "text":"Une petite créature volante en forme de cigare vous harcèle. À chaque passage, une vibration lui permet d'altérer votre cerveau et vous fait perdre **5 PV**. C'est un **Ronge-Méninges** (15 PV). Sans armure ni arme — seuls vos poings. Il frappe en premier.",
        "image":"assets/images/paragraphs/dream.png",
        "combat":{"enemy_id":"dream_nibbler","player_strikes_first":False,"on_win_paragraph":"dream_return","on_death_paragraph":"14"},
        "loot":[],"corruption_tier":None,
        "choices":[]
    },
    "dream_3": {
        "id":"dream_3","title":"Rêve : Le Vampire",
        "text":"Vous courez dans un cimetière, pourchassé par un **Vampire**. Lancez 2d6 pour la Force du vampire, puis 2d6 pour la vôtre. Si le vampire a une Force **5 points supérieure** à la vôtre → mort (§ 14). Sinon, vous lui échappez.",
        "image":"assets/images/paragraphs/dream.png",
        "combat":None,"loot":[],"corruption_tier":None,
        "is_special_encounter":"vampire_chase",
        "choices":[{"text":"Lancer les dés (résoudre la poursuite)","target_paragraph":"dream_return","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "dream_4": {
        "id":"dream_4","title":"Rêve : Les Deux Calices",
        "text":"Dans une grande salle de banquet, deux calices : l'un contient du **vin**, l'autre du **poison**. Vous devez boire l'un des deux. Lancez 2d6.\n\n- **> 6** : bon calice, rien ne se passe.\n- **≤ 6** : poison ! Relancez 2d6 et soustrayez ce résultat de vos PV.",
        "image":"assets/images/paragraphs/dream.png",
        "combat":None,"loot":[],"corruption_tier":None,
        "is_special_encounter":"poison_chalice",
        "choices":[{"text":"Choisir un calice (lancer les dés)","target_paragraph":"dream_return","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "dream_5": {
        "id":"dream_5","title":"Rêve : La Chute de la Tour",
        "text":"Vous vous glissez par une étroite fenêtre pour descendre en escalade une haute tour. La paroi est glissante. Lancez 2d6.\n\n- **< 6** : vous tombez ! Relancez pour savoir si vous tombez dans les douves (≥ 6, indemne) ou au sol (< 6, -10 PV). Si vous ne savez pas nager (< 6 encore), rendez-vous au § 14.\n- **≥ 6** : vous descendez sans tomber.",
        "image":"assets/images/paragraphs/dream.png",
        "combat":None,"loot":[],"corruption_tier":None,
        "is_special_encounter":"tower_fall",
        "choices":[{"text":"Tenter la descente (lancer les dés)","target_paragraph":"dream_return","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "dream_7": {
        "id":"dream_7","title":"Rêve : Les Abeilles (ou le Céleri…)",
        "text":"Vous vous promenez dans un jardin et soudain un **essaim d'abeilles** vous attaque. Chaque piqûre coûte 1 PV. Lancez 1d6 pour connaître le nombre d'abeilles qui vous atteignent.\n\n*Ou bien… un sortilège de Merlin a mal tourné et vous avez été transformé en **pied de céleri**. La chèvre approche. Lancez 1d6 : si < 6, elle vous grignote 5 PV.*",
        "image":"assets/images/paragraphs/dream.png",
        "combat":None,"loot":[],"corruption_tier":None,
        "is_special_encounter":"bees_or_celery",
        "choices":[{"text":"Subir l'attaque (lancer les dés)","target_paragraph":"dream_return","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "dream_8": {
        "id":"dream_8","title":"Rêve : Le Chevalier Noir",
        "text":"Vous affrontez le **Chevalier Noir** (25 PV, armure 6 pts, lance +10 dégâts). Vous portez une armure (protection 5 pts) et une **lance bénie** (+12 dégâts). Le roi Arthur lance 2d6 pour l'initiative : 2-6 → Chevalier en premier ; 7-12 → vous en premier.",
        "image":"assets/images/paragraphs/dream.png",
        "combat":{"enemy_id":"black_knight_dream","player_strikes_first":False,"on_win_paragraph":"dream_return","on_death_paragraph":"14"},
        "loot":[],"corruption_tier":None,"choices":[]
    },
    "dream_9": {
        "id":"dream_9","title":"Rêve : Le Monstre du Sommeil",
        "text":"Un **Monstre du Sommeil** couvert de poils vous fait face dans un couloir sinistre. Pas d'arme, pas d'armure. Deux coffrets sont à portée. Lancez 1d6 : **1-3** → dague magique (tue instantanément le monstre) ; **4-6** → gaz soporifique (vous vous rendormez et relancez dans le Temps du Rêve).",
        "image":"assets/images/paragraphs/dream.png",
        "combat":None,"loot":[],"corruption_tier":None,
        "is_special_encounter":"sleep_monster_chest",
        "choices":[{"text":"Ouvrir un coffret (lancer 1d6)","target_paragraph":"dream_return","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "dream_10": {
        "id":"dream_10","title":"Rêve : L'Ogre et les Flèches",
        "text":"Vous chassez le sanglier, armé d'un arc et **7 flèches** (10 dégâts chacune, touche sur 2d6 > 6). Dans une clairière, un **Ogre** (40 PV, +15 dégâts) s'apprête à dévorer une jeune fille. Vous avez 7 chances de le tuer avant qu'il vous atteigne, puis une dernière avec vos poings.",
        "image":"assets/images/paragraphs/dream.png",
        "combat":None,"loot":[],"corruption_tier":None,
        "is_special_encounter":"ogre_arrows",
        "choices":[{"text":"Tirer (lancer les dés pour chaque flèche)","target_paragraph":"dream_return","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "dream_11": {
        "id":"dream_11","title":"Rêve : L'Oubliette du Roi Arthur",
        "text":"Désaccord avec le roi Arthur sur la forme de la Terre : vous êtes jeté dans une oubliette sans eau ni nourriture. Lancez **1d6** : le résultat indique le nombre de jours d'emprisonnement (chaque jour = -1 PV). Puis vous êtes libéré.",
        "image":"assets/images/paragraphs/dream.png",
        "combat":None,"loot":[],"corruption_tier":None,
        "is_special_encounter":"dungeon_days",
        "choices":[{"text":"Subir la punition (lancer 1d6)","target_paragraph":"dream_return","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "dream_12": {
        "id":"dream_12","title":"Rêve : La Bataille Magique",
        "text":"Au sommet d'une montagne, vous affrontez un **Sorcier ennemi** en duel d'ondes magiques. Lancez **1d6** pour ses ondes restantes, et **1d6** pour les vôtres. Celui qui a le plus divise les PV de l'autre par 2.",
        "image":"assets/images/paragraphs/dream.png",
        "combat":None,"loot":[],"corruption_tier":None,
        "is_special_encounter":"magic_duel",
        "choices":[{"text":"Lancer les dés pour le duel","target_paragraph":"dream_return","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    },
    "dream_return": {
        "id":"dream_return","title":"Retour du Rêve",
        "text":"Vous vous réveillez en sueur, mais vivant. Le Temps du Rêve vous a rendu...\n\nVous reprenez l'aventure là où vous l'aviez laissée.",
        "image":None,"combat":None,"loot":[],"corruption_tier":None,
        "is_dream_return":True,
        "choices":[{"text":"Reprendre l'aventure","target_paragraph":"__return_to_previous__","requires_item":None,"requires_gold":None,"hidden_if_missing":False}]
    }
}

# ══════════════════════════════════════════════════════════════
#  MÉTADONNÉES DE COMBAT (enrichissement manuel des §)
# ══════════════════════════════════════════════════════════════

COMBAT_META = {
    "10":  {"enemy_id":"boar",         "player_strikes_first":False,"on_win_paragraph":"22","on_death_paragraph":"14"},
    "21":  {"enemy_id":"wolf",         "player_strikes_first":True, "on_win_paragraph":"21_win","on_death_paragraph":"14"},
    "28":  {"enemy_id":"mastiff",      "player_strikes_first":None, "on_win_paragraph":"141","on_death_paragraph":"14","multi":True,"count":2},
    "35":  {"enemy_id":"vegetable_monster","player_strikes_first":False,"on_win_paragraph":"39","on_death_paragraph":"14"},
    "43":  {"enemy_id":"spider",       "player_strikes_first":True, "on_win_paragraph":"80","on_death_paragraph":"14"},
    "44":  {"enemy_id":"zombie",       "player_strikes_first":True, "on_win_paragraph":"42","on_death_paragraph":"14","multi":True,"count":6,"special":"zombie_kill_only_on_9_12"},
    "47":  {"enemy_id":"skeleton",     "player_strikes_first":True, "on_win_paragraph":"131","on_death_paragraph":"14"},
    "48":  {"enemy_id":"old_man_traitor","player_strikes_first":False,"on_win_paragraph":"155","on_death_paragraph":"14"},
    "64":  {"enemy_id":"spider",       "player_strikes_first":True, "on_win_paragraph":"80","on_death_paragraph":"14"},
    "86":  {"enemy_id":"guard",        "player_strikes_first":False,"on_win_paragraph":"107","on_death_paragraph":"14","multi":True,"count":2},
    "90":  {"enemy_id":"goblin",       "player_strikes_first":True, "on_win_paragraph":"110","on_death_paragraph":"14"},
    "95":  {"enemy_id":"guard",        "player_strikes_first":True, "on_win_paragraph":"138","on_death_paragraph":"14","multi":True,"count":2},
    "97":  {"enemy_id":"goblin",       "player_strikes_first":True, "on_win_paragraph":"75","on_death_paragraph":"14"},
    "99":  {"enemy_id":"guard_elite",  "player_strikes_first":False,"on_win_paragraph":"150","on_death_paragraph":"14"},
    "130": {"enemy_id":"ansalom_dogs", "player_strikes_first":True, "on_win_paragraph":"137","on_death_paragraph":"14","multi":True,"count":2},
    "137": {"enemy_id":"ansalom",      "player_strikes_first":True, "on_win_paragraph":"135","on_death_paragraph":"14"},
    "142": {"enemy_id":"guard",        "player_strikes_first":False,"on_win_paragraph":"125","on_death_paragraph":"14"},
    "144": {"enemy_id":"demon_invisible","player_strikes_first":False,"on_win_paragraph":"129","on_death_paragraph":"14"},
}

# Loot trouvé dans certains paragraphes
LOOT_META = {
    "39":  [{"type":"gold","amount":10}],
    "42":  [{"type":"item","item_id":"silver_ring","name":"Anneau d'argent gravé","description":"Inscriptions mystérieuses. Peut être magique.","item_type":"quest"}],
    "83":  [{"type":"item","item_id":"teleport_scroll","name":"Parchemin de Téléportage","description":"Utilisable une fois. Vous ramène au § 14 vivant avec tout votre équipement.","item_type":"magic","uses_remaining":1,"uses_total":1}],
    "88":  [{"type":"item","item_id":"heal_scroll","name":"Parchemin Curatif","description":"Restaure tous vos PV de départ. Une seule utilisation.","item_type":"magic","uses_remaining":1,"uses_total":1}],
    "93":  [{"type":"item","item_id":"hypnosis_scroll","name":"Parchemin d'Hypnose","description":"Lance 1d6. ≥ 5 = ennemi neutralisé (traiter comme victoire). Une seule utilisation.","item_type":"magic","uses_remaining":1,"uses_total":1}],
    "97":  [{"type":"item","item_id":"antidote_scroll","name":"Parchemin d'Antidote","description":"Neutralise un empoisonnement même fatal. Une seule utilisation.","item_type":"magic","uses_remaining":1,"uses_total":1}],
    "103": [{"type":"special","effect":"heal_to_max_plus_25_temp","description":"Calice de la Dame du Lac : PV remis à zéro + 25 PV temporaires bonus."}],
    "132": [{"type":"item","item_id":"vampire_ring","name":"Bague du Vampire","description":"Pierre précieuse. Valeur ≥ 500 P.O.","item_type":"quest"}],
    "141": [{"type":"item","item_id":"diamond","name":"Diamant","description":"Valeur estimée : 170 P.O. Peut être magique.","item_type":"quest"}],
    "143": [
        {"type":"gold","amount":500},
        {"type":"item","item_id":"emeralds","name":"Émeraudes (25)","description":"Chacune vaut 500 P.O.","item_type":"quest"},
        {"type":"item","item_id":"rubies","name":"Rubis (61)","description":"Chacun vaut 100 P.O.","item_type":"quest"},
        {"type":"item","item_id":"diamonds_hoard","name":"Diamants (77)","description":"Chacun vaut 1 000 P.O.","item_type":"quest"},
    ],
}

# Corruption tier par paragraphe
CORRUPTION_TIERS = {
    "35": 1, "44": 2, "86": 2, "89": 2, "90": 3, "99": 3, "142": 3
}

# ══════════════════════════════════════════════════════════════
#  PARSER PRINCIPAL
# ══════════════════════════════════════════════════════════════

def clean_text(t: str) -> str:
    """Nettoyage minimal du texte brut."""
    # Supprimer les fragments de lignes orphelines très courts (artefacts OCR)
    lines = t.splitlines()
    cleaned = []
    for line in lines:
        stripped = line.strip()
        if len(stripped) < 4 and stripped and not stripped.isdigit():
            continue
        cleaned.append(line)
    text = "\n".join(cleaned).strip()
    # Normaliser les espaces multiples
    text = re.sub(r' {2,}', ' ', text)
    # Normaliser les sauts de ligne multiples
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text

def parse_choices(text: str) -> list[dict]:
    """Extrait les choix de navigation depuis le texte d'un paragraphe."""
    choices = []
    seen_targets = set()

    patterns = [
        # "rendez-vous au 42" / "Rendez-vous au 42."
        r'[Rr]endez[-\s]vous au\s+(\d+)',
        # "au 42)" / "(rendez-vous au 42"
        r'\bau\s+(\d+)[,\.\)]',
    ]

    # Chercher les phrases contenant un renvoi
    sentences = re.split(r'(?<=[.!?])\s+', text)
    for sentence in sentences:
        for pat in patterns:
            for m in re.finditer(pat, sentence):
                target = m.group(1)
                if target in seen_targets:
                    continue
                seen_targets.add(target)

                # Extraire le texte du choix depuis la phrase
                # Chercher ce qui précède "rendez-vous"
                choice_text_match = re.search(
                    r'(?:Si vous\s+(.{5,80}?)(?:,?\s*r[Rr]endez)|(?:^|\n)\s*(.{5,80}?),?\s*[Rr]endez)',
                    sentence, re.IGNORECASE
                )
                if choice_text_match:
                    raw = (choice_text_match.group(1) or choice_text_match.group(2) or "").strip()
                    raw = re.sub(r'\s+', ' ', raw).strip(', ')
                    if len(raw) > 3:
                        label = raw[:120]
                    else:
                        label = f"→ Paragraphe {target}"
                else:
                    label = f"→ Paragraphe {target}"

                choices.append({
                    "text": label,
                    "target_paragraph": target,
                    "requires_item": None,
                    "requires_gold": None,
                    "hidden_if_missing": False
                })
                break  # une correspondance par phrase

    return choices

def parse_paragraphs(md_text: str) -> dict:
    """
    Découpe le Markdown en paragraphes numérotés.
    Retourne {id_str: paragraph_dict}
    """
    paragraphs = {}

    # Pattern : ligne qui contient uniquement un numéro (éventuellement suivi de *C)
    # Le numéro peut être précédé/suivi de lignes vides
    para_split = re.split(
        r'\n\s*(\d{1,3})(\*{0,4}C?)\s*\n',
        md_text
    )

    # para_split alterne : [préambule, id, corruption_suffix, contenu, id, corruption_suffix, contenu, ...]
    i = 1
    while i < len(para_split) - 2:
        pid      = para_split[i].strip()
        csuffix  = para_split[i+1].strip()
        content  = para_split[i+2]
        i += 3

        # Calculer le tier de corruption
        corruption_tier = CORRUPTION_TIERS.get(pid)
        if not corruption_tier and csuffix:
            stars = csuffix.replace('C', '').count('*')
            if stars > 0:
                corruption_tier = stars

        raw_text = clean_text(content)
        if not raw_text or len(raw_text) < 10:
            continue

        # Titre : première phrase courte ou les 60 premiers caractères
        first_line = raw_text.splitlines()[0][:80].strip()
        title = first_line if len(first_line) > 3 else f"Paragraphe {pid}"

        choices = parse_choices(raw_text)

        # Combat intégré ?
        combat = None
        if pid in COMBAT_META:
            c = COMBAT_META[pid]
            combat = {
                "enemy_id": c["enemy_id"],
                "player_strikes_first": c.get("player_strikes_first", True),
                "on_win_paragraph": c["on_win_paragraph"],
                "on_death_paragraph": c["on_death_paragraph"],
                "multi_count": c.get("count", 1),
                "special": c.get("special")
            }

        loot = LOOT_META.get(pid, [])

        paragraphs[pid] = {
            "id": pid,
            "title": title,
            "text": raw_text,
            "image": f"assets/images/paragraphs/p{pid}.png",
            "combat": combat,
            "loot": loot,
            "corruption_tier": corruption_tier,
            "is_death_paragraph": (pid == "14"),
            "grants_xp": 1 if combat else 0,
            "choices": choices
        }

    return paragraphs

def post_process(paragraphs: dict) -> dict:
    """Corrections manuelles post-parsing."""

    # § 14 — Mort : remplacer les choix auto-détectés
    if "14" in paragraphs:
        paragraphs["14"]["choices"] = [{
            "text": "Recommencer l'aventure (recalculer les PV)",
            "target_paragraph": "intro",
            "requires_item": None, "requires_gold": None,
            "hidden_if_missing": False, "resets_game": True
        }]

    # § 21 — Victoire sur le Loup (paragraphe synthétique)
    if "21_win" not in paragraphs:
        paragraphs["21_win"] = {
            "id": "21_win", "title": "Victoire sur le Loup",
            "text": "Le Loup s'effondre. **+1 Point d'Expérience**. Que faites-vous ?",
            "image": None, "combat": None, "loot": [], "corruption_tier": None,
            "grants_xp": 1,
            "choices": [
                {"text":"Revenir sur vos pas → sentier de gauche","target_paragraph":"20","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
                {"text":"Continuer → nouveau sentier de droite","target_paragraph":"10","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
                {"text":"Continuer → sentier de gauche","target_paragraph":"22","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            ]
        }

    # § 8 : forcer les choix de départ de la forêt
    if "8" in paragraphs:
        paragraphs["8"]["choices"] = [
            {"text":"Prendre le sentier de droite","target_paragraph":"9","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"Prendre le sentier de gauche","target_paragraph":"20","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
        ]

    # § 19 : entrée du château
    if "19" in paragraphs:
        paragraphs["19"]["choices"] = [
            {"text":"Traverser le pont-levis et entrer dans le château","target_paragraph":"23","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
        ]

    # § 135 → victoire
    if "135" in paragraphs:
        paragraphs["135"]["choices"] = [
            {"text":"Chercher la geôle de la Reine derrière le trône","target_paragraph":"victory","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
        ]

    # § 103 — Dame du Lac
    if "103" in paragraphs:
        paragraphs["103"]["loot"] = LOOT_META.get("103", [])

    # § 52 — Squelette amical (Silas) → indice sur la trappe
    if "52" in paragraphs:
        paragraphs["52"]["choices"] = [
            {"text":"Écouter le Squelette — il révèle une trappe secrète","target_paragraph":"41","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
        ]

    # § 101 — Crypte de Nosfèrax : choix de frappes
    if "101" in paragraphs:
        paragraphs["101"]["choices"] = [
            {"text":"Frapper UNE fois","target_paragraph":"84","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"Frapper DEUX fois","target_paragraph":"104","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"Frapper TROIS fois","target_paragraph":"109","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"Frapper QUATRE fois","target_paragraph":"102","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
        ]

    # § 132 — Ail contre Nosfèrax (victoire automatique si l'objet est possédé)
    if "132" in paragraphs:
        paragraphs["132"]["choices"] = [
            {"text":"Montrer l'ail à Nosfèrax","target_paragraph":"132_garlic","requires_item":"garlic","requires_gold":None,"hidden_if_missing":False},
            {"text":"Combattre Nosfèrax","target_paragraph":"132_fight","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
        ]

    # § 43 — Araignée : choix de réaction
    if "43" in paragraphs:
        paragraphs["43"]["choices"] = [
            {"text":"Tenter une Réaction Amicale avec l'Araignée","target_paragraph":"70","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"Combattre l'Araignée Géante","target_paragraph":"64","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
            {"text":"Tenter de bondir hors de la fosse","target_paragraph":"66","requires_item":None,"requires_gold":None,"hidden_if_missing":False},
        ]

    return paragraphs

def build_output(md_path: str) -> dict:
    with open(md_path, 'r', encoding='utf-8') as f:
        md_text = f.read()

    paragraphs = parse_paragraphs(md_text)
    paragraphs = post_process(paragraphs)

    # Ajouter les paragraphes manuels
    for k, v in MANUAL_PARAGRAPHS.items():
        paragraphs[k] = v

    # Trier par ID numérique puis alphanumérique
    def sort_key(k):
        try:
            return (0, int(k))
        except ValueError:
            return (1, k)

    paragraphs_sorted = dict(sorted(paragraphs.items(), key=lambda x: sort_key(x[0])))

    return {
        "_schema_version": "2.0.0",
        "_game_title": "La Quête du Graal — Le Château des Ténèbres",
        "_paragraph_count": len(paragraphs_sorted),
        "game_config": GAME_CONFIG,
        "enemies": ENEMIES,
        "paragraphs": paragraphs_sorted
    }

if __name__ == "__main__":
    md_file = sys.argv[1] if len(sys.argv) > 1 else "source.md"
    out_file = sys.argv[2] if len(sys.argv) > 2 else "assets/data/game_structure.json"

    print(f"📖 Parsing {md_file}...")
    output = build_output(md_file)

    Path(out_file).parent.mkdir(parents=True, exist_ok=True)
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    n_para = output["_paragraph_count"]
    print(f"✅ {n_para} paragraphes générés → {out_file}")
    print(f"   Ennemis définis : {len(output['enemies'])}")
    print(f"   Dont paragraphes avec combat : {sum(1 for p in output['paragraphs'].values() if p.get('combat'))}")
    print(f"   Dont paragraphes avec loot   : {sum(1 for p in output['paragraphs'].values() if p.get('loot'))}")
