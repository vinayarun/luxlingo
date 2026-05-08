#!/usr/bin/env python3
"""Fetch verb paradigms + audio from lod.lu and inject into iOS initial_seed.json."""

import json, urllib.request, time, shutil, datetime

SEED_PATH = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
BASE_URL   = 'https://lod.lu/api/lb/entry/'
PERSONS    = ['ech', 'du', 'hien/si/et', 'mir', 'dir', 'si']
NEW_VERSION = None  # bumped relative to current version

# ── diacritic-stripping for lod_id construction ───────────────────────────────
DIACRITIC_MAP = str.maketrans({
    'ë':'e','é':'e','è':'e','ê':'e',
    'ä':'a','à':'a','â':'a',
    'ö':'o','ô':'o',
    'ü':'u','û':'u','ù':'u',
    'î':'i','ï':'i',
    'ç':'c','ó':'o','á':'a','í':'i',
})

def to_lod_id(word, n=1):
    word = word.strip().rstrip('-').lower()
    word = word.translate(DIACRITIC_MAP)
    word = ''.join(c for c in word if c.isalpha())
    return word.upper() + str(n)

def fetch_entry(word_lu, n=1):
    lod_id = to_lod_id(word_lu, n)
    try:
        req = urllib.request.Request(
            BASE_URL + lod_id,
            headers={'Accept': 'application/json', 'User-Agent': 'LuxLingo/1.0'}
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            return json.loads(resp.read())
    except Exception:
        return None

def extract_present(entry):
    tables = entry.get('entry', {}).get('tables', {})
    present = tables.get('verbConjugation', {}).get('indicative', {}).get('present', {})
    if not present:
        return None
    return [
        f"ech {present.get('p1','?')}",
        f"du {present.get('p2','?')}",
        f"hien/si/et {present.get('p3','?')}",
        f"mir {present.get('p4','?')}",
        f"dir {present.get('p5','?')}",
        f"si {present.get('p6','?')}",
    ]

def extract_participle(entry):
    conj = entry.get('entry', {}).get('tables', {}).get('verbConjugation', {})
    pp  = conj.get('pastParticiple', '')
    aux = conj.get('auxiliaryVerb', '')
    # pastParticiple can be "gemaach / gemaacht" — take first form
    pp = pp.split('/')[0].strip() if pp else ''
    return pp or None, aux or None

def get_audio(entry):
    af = entry.get('entry', {}).get('audioFiles', {})
    return af.get('aac', af.get('ogg', ''))

def is_verb_pos(pos):
    return 'VRB' in pos or pos.upper() in ('VERB',)

def main():
    bk = SEED_PATH + f'.bak_{datetime.datetime.now().strftime("%Y%m%d_%H%M%S")}'
    shutil.copy2(SEED_PATH, bk)
    print(f'Backup: {bk}\n')

    with open(SEED_PATH, encoding='utf-8') as f:
        data = json.load(f)

    vocab_map = {v['surface_id']: v for v in data['vocabulary']}

    # Deduplicated verb senses (first occurrence wins)
    seen_sids = set()
    verb_senses = []
    for s in data['senses']:
        sid = s['sense_id']
        if sid not in seen_sids and is_verb_pos(s.get('pos', '')):
            seen_sids.add(sid)
            verb_senses.append(s)

    print(f'Verb senses to process: {len(verb_senses)}\n')

    paradigms    = {}   # sense_id -> list[str]
    participles  = {}   # sense_id -> {'form': str, 'aux': str}
    audio_urls   = {}   # surface_id -> str

    for s in verb_senses:
        sid    = s['sense_id']
        surf   = s.get('surface_id', '')
        vocab  = vocab_map.get(surf, {})
        word   = vocab.get('word_lu', '').rstrip('-')
        pos    = s.get('pos', '')

        # VRBPART (separable-verb prefixes like no-, kleng-) have no conjugation table
        if pos == 'VRBPART':
            print(f'  SKIP  {sid} ({word}) — verbal particle, no paradigm')
            continue

        # Try lod_id numbers 1-3 in case of polysemy
        entry = None
        for n in range(1, 4):
            e = fetch_entry(word, n)
            if e and e.get('entry', {}).get('partOfSpeech') in ('VRB', 'VERB'):
                entry = e
                break

        if entry:
            present   = extract_present(entry)
            pp, aux   = extract_participle(entry)
            audio_url = get_audio(entry)
            lod_id    = entry['entry']['lod_id']
            if present:
                paradigms[sid] = present
                print(f'  ✅  {sid} ({word}) [{lod_id}]: {present[0]}, {present[3]}', end='')
                if pp:
                    participles[sid] = {'form': pp, 'aux': aux or 'hunn'}
                    print(f'  pp={pp} aux={aux}', end='')
                print()
            else:
                print(f'  ⚠️   {sid} ({word}) [{lod_id}]: no paradigm table in lod.lu')
            if audio_url:
                audio_urls[surf] = audio_url
        else:
            print(f'  ❌  {sid} ({word}): not found as VRB in lod.lu')

        time.sleep(0.1)

    # ── Apply to all sense occurrences ────────────────────────────────────────
    s_updated = 0
    for s in data['senses']:
        sid = s['sense_id']
        if sid in paradigms:
            if 'paradigm' not in s:
                s['paradigm'] = {}
            s['paradigm']['present'] = paradigms[sid]
            if sid in participles:
                s['paradigm']['past_participle'] = participles[sid]['form']
                s['paradigm']['auxiliary'] = participles[sid]['aux']
            s_updated += 1

    # ── Apply audio URLs to vocabulary ────────────────────────────────────────
    v_updated = 0
    for v in data['vocabulary']:
        surf = v['surface_id']
        if surf in audio_urls:
            v['lod_audio_url'] = audio_urls[surf]
            v_updated += 1

    # ── Bump version to trigger iOS re-seed ───────────────────────────────────
    old_ver = data.get('version', 0)
    data['version'] = round(float(old_ver) + 0.1, 1)

    with open(SEED_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f'\nSenses updated with paradigm : {s_updated}')
    print(f'Vocab updated with audio URL  : {v_updated}')
    print(f'Version bumped: {old_ver} → {NEW_VERSION}')
    print(f'Saved: {SEED_PATH}')

if __name__ == '__main__':
    main()
