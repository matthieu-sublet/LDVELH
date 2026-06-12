#!/usr/bin/env python3
"""
parse_graal_v2.py — Parseur complet respectant le sommaire officiel
"""
import re, json, sys
from pathlib import Path

# ══════════════════════════════════════════════════════════════
#  POSITIONS DES SECTIONS (détectées dynamiquement)
# ══════════════════════════════════════════════════════════════

SECTION_PATTERNS = {
    "merlin":   r'##\s*Merlin\b',
    "avis":     r'##\s*Avis\s+concernant\s+le\s+jeu',
    "avalon":   r'##\s*Le\s+Royaume\s+d.?Avalon',
    "mission":  r'##\s*La\s+mission\s+de\s+Pip',
    "reine":    r'##\s*La\s+Reine\s+Guenièvre',
    "chateau":  r'##\s*Le\s+Château\s+des\s+Ténèbres\s+du\s+Sorcier',
    "chateau2": r'##\s*Au\s+cœur\s+du\s+Château',
    "triomphe": r'##\s*Le\s+triomphe\s+de\s+Pip',
    "reve":     r'Le\s+Temps\s+du\s+Rêve\s*\n',
    "regles":   r'##\s*Règles\s+des\s+combats',
}

def find_sections(text):
    pos = {}
    for k, pat in SECTION_PATTERNS.items():
        m = re.search(pat, text, re.IGNORECASE | re.MULTILINE)
        if m:
            pos[k] = (m.start(), m.end())
    return pos

def between(text, pos, key_start, key_end):
    s = pos.get(key_start)
    e = pos.get(key_end)
    if not s:
        return ""
    start = s[1]  # après le titre
    end = e[0] if e else len(text)
    return text[start:end].strip()

# ══════════════════════════════════════════════════════════════
#  NETTOYAGE
# ══════════════════════════════════════════════════════════════

def clean(text):
    text = re.sub(r'\*\*==>.*?<==\*\*', '', text, flags=re.DOTALL)
    text = re.sub(r'\*\*-+\s*Start of picture text.*?End of picture text\s*-+\*\*', '', text, flags=re.DOTALL)
    text = re.sub(r'[ \t]{2,}', ' ', text)
    # Fusionner sauts simples en espace, conserver doubles
    text = re.sub(r'(?<!\n)\n(?!\n)', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()

# ══════════════════════════════════════════════════════════════
#  CHOIX ET ENNEMIS
# ══════════════════════════════════════════════════════════════

RE_CHOICE = re.compile(
    r'rendez\s*[- ]?\s*vous(?:\s+donc|\s+directement)?\s+au\s+\**(\d+)\**',
    re.IGNORECASE
)
RE_ENEMY = re.compile(
    r'([A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ\s\-\']{1,40}?)\s*(?:dispose de|possède)\s*(\d+)\s*POINTS?\s*DE\s*VIE',
    re.IGNORECASE
)

def extract_choices(text):
    seen, choices = set(), []
    for m in RE_CHOICE.finditer(text):
        nid = m.group(1)
        if nid in seen:
            continue
        seen.add(nid)
        snippet = text[max(0, m.start()-180):m.start()]
        parts = re.split(r'[.!?]\s+', snippet)
        label = parts[-1].strip().lstrip(' ,;:') if parts else ''
        if len(label) < 3:
            label = f"→ Aller au paragraphe {nid}"
        choices.append({"text": label[:200], "nextId": nid})
    return choices

def extract_enemy(text):
    m = RE_ENEMY.search(text)
    if not m:
        return None
    name = m.group(1).strip().rstrip(' ,.')
    if len(name) < 2 or name.lower() in ('vous','il','elle','ce','cet'):
        return None
    dmg = re.search(r'(\d+)\s*Points?\s*de\s*Dommage\s*supplémentaires', text, re.IGNORECASE)
    return {
        "name": name,
        "lifePoints": int(m.group(2)),
        "extraDamage": int(dmg.group(1)) if dmg else 0
    }

# ══════════════════════════════════════════════════════════════
#  PARAGRAPHES DE JEU
# ══════════════════════════════════════════════════════════════

RE_PARA = re.compile(r'(?:^|\n)\s*(\d{1,3})(\*{0,4}C?)\s*\n')

def parse_paragraphs(text):
    parts = RE_PARA.split(text)
    paras, seen = [], set()
    i = 1
    while i < len(parts) - 2:
        pid, csuffix, content = parts[i].strip(), parts[i+1].strip(), parts[i+2]
        i += 3
        raw = clean(content)
        if not raw or len(raw) < 15 or pid in seen:
            continue
        seen.add(pid)
        stars = csuffix.replace('C','').count('*')
        first = re.split(r'[.!?\n]', raw)[0][:80].strip()
        paras.append({
            "id": pid,
            "title": first,
            "text": raw,
            "corruptionTier": stars if stars > 0 else None,
            "enemy": extract_enemy(raw),
            "choices": extract_choices(raw),
            "canDie": bool(re.search(r'rendez\s*[- ]?\s*vous\s+au\s+14\b', raw, re.IGNORECASE)),
        })
    return sorted(paras, key=lambda x: int(x['id']))

# ══════════════════════════════════════════════════════════════
#  TEMPS DU RÊVE
# ══════════════════════════════════════════════════════════════

RE_DREAM_SEC = re.compile(r'(?:^|\n)\s*(2|3|4|5|6|7|8|9|10|11|12)\s*[:;]\s*', re.MULTILINE)

def parse_dream(text):
    # Description avant la section 2
    first = RE_DREAM_SEC.search(text)
    description = clean(text[:first.start()]) if first else ""

    parts = RE_DREAM_SEC.split(text)
    sections = []
    i = 1
    while i < len(parts) - 1:
        sid = parts[i].strip()
        content = clean(parts[i+1]) if i+1 < len(parts) else ""
        i += 2
        if content:
            sections.append({
                "id": sid,
                "text": content,
                "choices": extract_choices(content),
            })
    return {"description": description, "sections": sections}

# ══════════════════════════════════════════════════════════════
#  ASSEMBLAGE PRINCIPAL
# ══════════════════════════════════════════════════════════════

def build(md_path):
    with open(md_path, 'r', encoding='utf-8') as f:
        raw = f.read()

    pos = find_sections(raw)

    # Textes bruts par section
    merlin_txt   = between(raw, pos, "merlin",   "avis")
    avis_txt     = between(raw, pos, "avis",     "avalon")
    avalon_txt   = between(raw, pos, "avalon",   "mission")
    mission_txt  = between(raw, pos, "mission",  "reine")
    reine_txt    = between(raw, pos, "reine",    "chateau")
    # Château = chateau1 + chateau2 fusionnés
    ch1_txt      = between(raw, pos, "chateau",  "chateau2")
    ch2_txt      = between(raw, pos, "chateau2", "triomphe")
    chateau_txt  = ch1_txt + "\n\n" + ch2_txt
    triomphe_txt = between(raw, pos, "triomphe", "reve")
    reve_txt     = between(raw, pos, "reve",     "regles")
    regles_txt   = between(raw, pos, "regles",   None)

    # Paragraphes de jeu
    mission_paras = parse_paragraphs(mission_txt)
    chateau_paras = parse_paragraphs(chateau_txt)

    # Temps du Rêve
    temps_reve = parse_dream(reve_txt)

    histoire = [
        {
            "order": 1, "id": "ch_merlin",
            "title": "Merlin",
            "type": "narration",
            "contenu": clean(merlin_txt),
            "suivant": "ch_avalon",
        },
        {
            "order": 2, "id": "ch_avalon",
            "title": "Le Royaume d'Avalon",
            "type": "narration",
            "contenu": clean(avalon_txt),
            "suivant": "ch_mission",
        },
        {
            "order": 3, "id": "ch_mission",
            "title": "La mission de Pip",
            "type": "jeu",
            "paragrapheDepart": mission_paras[0]['id'] if mission_paras else "1",
            "paragraphes": mission_paras,
        },
        {
            "order": 4, "id": "ch_reine",
            "title": "La reine Guenièvre a disparu",
            "type": "narration",
            "contenu": clean(reine_txt),
            "suivant": "ch_chateau",
        },
        {
            "order": 5, "id": "ch_chateau",
            "title": "Le Château des Ténèbres",
            "type": "jeu",
            "paragrapheDepart": chateau_paras[0]['id'] if chateau_paras else "9",
            "paragraphes": chateau_paras,
        },
        {
            "order": 6, "id": "ch_triomphe",
            "title": "Le triomphe de Pip",
            "type": "narration",
            "contenu": clean(triomphe_txt),
            "suivant": None,
        },
    ]

    return {
        "_schema": "3.0",
        "_title": "La Quête du Graal — Le Château des Ténèbres",
        "_stats": {
            "mission_paragraphes":  len(mission_paras),
            "chateau_paragraphes":  len(chateau_paras),
            "dream_sections":       len(temps_reve['sections']),
        },
        "annexes": {
            "avis_jeu":       clean(avis_txt),
            "regles_combats": clean(regles_txt),
        },
        "tempsDuReve": temps_reve,
        "histoire": histoire,
    }

# ══════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    md  = sys.argv[1] if len(sys.argv) > 1 else "source.md"
    out = sys.argv[2] if len(sys.argv) > 2 else "assets/data/game_structure.json"
    print(f"📖 Parsing {md}...")
    book = build(md)
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(book, f, ensure_ascii=False, indent=2)
    s = book['_stats']
    print(f"✅ {out}")
    print(f"   Mission de Pip       : {s['mission_paragraphes']} paragraphes")
    print(f"   Château des Ténèbres : {s['chateau_paragraphes']} paragraphes")
    print(f"   Temps du Rêve        : {s['dream_sections']} sections")
    print(f"   Chapitres            : {len(book['histoire'])}")
