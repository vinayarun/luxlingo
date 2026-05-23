#!/usr/bin/env python3
"""
Import LLM-generated English sentences, translate via LuxMT, validate,
and inject into initial_seed.json.

Usage:
  1. Feed sentence_generation_prompt.md to any LLM.
  2. Save the JSON output to a file (e.g. llm_sentences.json).
  3. Run: python3 import_sentences.py llm_sentences.json

The script applies A+B+C quality filters:
  A. Rejects sentences containing "will" (future tense) for simple difficulty.
  B. Calls LuxMT up to MAX_RETRIES times and picks the shortest valid translation.
  C. Rejects translations containing Luxembourgish complexity markers (wäert, etc.)
     for simple difficulty.
  Validation: target word (lemma, n-rule form, or paradigm form) must appear in LB output.
"""

import json, sys, re, time, shutil, datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

SEED_PATH    = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
LUXMT_URL    = 'https://luxasr.uni.lu/luxmt/translate'
MAX_RETRIES  = 3
LUXMT_WORKERS = 6

# Luxembourgish complexity markers to reject in simple sentences
LB_COMPLEXITY = ['wäert', 'géif', 'wier', 'hätt', 'wann ech', 'obwuel', 'well ech']

# Declined / variant / synonym forms accepted per lemma (lowercase keys).
# Covers adjective declension, pronoun inflection, spelling variants, and LuxMT synonyms.
LB_DECLINED_FORMS = {
    'aner':   {'aneren', 'anere', 'anerem', 'anerer', 'anert', 'anner', 'anneren', 'annere', 'annert'},
    'eent':   {'een', 'eng', 'e', 'engem', 'enger'},
    'en':     {'eng', 'engem', 'enger'},       # indefinite article declension
    'hir':    {'hire', 'hiren', 'hiert', 'hirem', 'hirer'},
    'dëst':   {'dësen', 'dës', 'dësem', 'dëser', 'dëse'},
    'dat':    {'dee', 'deen', 'dës', 'dëser', 'dësem', 'dass'},  # demonstrative + conjunction
    'déi':    {'si', 'se'},                    # LuxMT uses si/se for "they"
    'si':     {'se'},                          # clitic/unstressed form in subordinate clauses
    'hien':   {'him', 'en'},                   # dative and clitic forms
    'säin':   {'säi', 'seng', 'sengen', 'sengem', 'senger'},
    'keen':   {'keng', 'kengem', 'kenger', 'keenge', 'keengen'},
    'waarm':  {'waarmen', 'waarmer', 'waarmt', 'waarme'},
    'mä':     {'awer', 'mee'},                 # LuxMT synonyms for "but"
    'wäert':  {'wäerten', 'wäerts'},           # plural/2nd-person conjugation
    'wann':   {'wenn'},                        # German-influenced spelling LuxMT uses
    'nees':   {'erëm'},                        # LuxMT prefers erëm (synonym)
    'mënsch': {'persoun', 'persoune', 'mënschen', 'mënsches'},  # LuxMT prefers Persoun
    'wuert':  {'wort', 'wuerts', 'worts'},     # LuxMT sometimes uses German spelling
}

PUNCT = str.maketrans('', '', '.,!?;:\'"„"«»()[]')


def load_seed():
    with open(SEED_PATH, encoding='utf-8') as f:
        return json.load(f)

def save_seed(data):
    with open(SEED_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def clean(word):
    return word.translate(PUNCT).lower()

def paradigm_forms(sense):
    forms = set()
    for row in sense.get('paradigm', {}).get('present', []):
        # Rows may be "PRONOUN VERB" or "PRONOUN VERB (REFL_PRON)"
        # Strip parenthesised tokens, then take the last remaining word
        parts = [p for p in row.split() if not p.startswith('(')]
        if parts:
            forms.add(parts[-1].lower())
    pp = sense.get('paradigm', {}).get('past_participle', '')
    if pp:
        forms.add(pp.lower())
    return forms

def word_present(text_lu, lemma, sense):
    # Split on spaces AND apostrophes so "d'anner" → ["d", "anner"]
    raw = re.split(r"[\s'']+", text_lu)
    words = [clean(w) for w in raw if w]
    lc = clean(lemma)
    if lc in words:
        return True
    if lc.endswith('n') and len(lc) > 1 and lc[:-1] in words:
        return True
    for f in paradigm_forms(sense):
        if f in words:
            return True
    # Check declined / variant / synonym forms
    extra = LB_DECLINED_FORMS.get(lc, set())
    if any(f in words for f in extra):
        return True
    return False

def is_complex_lb(text_lu, difficulty, sense_id=''):
    """Return True if translation is too complex for the given difficulty."""
    if difficulty != 'simple':
        return False
    # wäert is the word being taught for s_wäert_1 — never reject it
    if sense_id == 's_wäert_1':
        return False
    low = text_lu.lower()
    return any(m in low for m in LB_COMPLEXITY)

def filter_a(text_en, difficulty, sense_id=''):
    """Filter A: reject 'will' in simple sentences (except wäert, which IS the word 'will')."""
    if difficulty == 'simple' and re.search(r'\bwill\b', text_en, re.I):
        return sense_id == 's_wäert_1'
    return True

def _translate_once(text_en):
    try:
        resp = requests.post(
            LUXMT_URL,
            json={'text': text_en, 'source_lang': 'en', 'target_lang': 'lb'},
            timeout=15
        )
        if resp.status_code == 200:
            return resp.json().get('translated_text')
    except Exception:
        pass
    return None

def translate_with_retry(text_en, difficulty, word_lu, sense):
    """
    Filter B+C: translate up to MAX_RETRIES times, return shortest valid result.
    Skips translations that contain complexity markers (filter C).
    """
    sense_id = sense.get('sense_id', '')
    candidates = []
    for _ in range(MAX_RETRIES):
        lu = _translate_once(text_en)
        time.sleep(0.2)
        if not lu:
            continue
        if is_complex_lb(lu, difficulty, sense_id):
            continue  # filter C
        candidates.append(lu)

    if not candidates:
        return None

    # Filter B: pick shortest (fewest words = simpler structure)
    return min(candidates, key=lambda s: len(s.split()))


def main():
    if len(sys.argv) < 2:
        print('Usage: python3 import_sentences.py <llm_output.json>')
        sys.exit(1)

    input_file = sys.argv[1]
    with open(input_file, encoding='utf-8') as f:
        raw = f.read().strip()
        # Strip markdown code fences if LLM wrapped the JSON
        raw = re.sub(r'^```(?:json)?\s*', '', raw, flags=re.M)
        raw = re.sub(r'\s*```$', '', raw, flags=re.M)
        llm_sentences = json.loads(raw)

    print(f'Loaded {len(llm_sentences)} sentences from {input_file}')

    bk = f'{SEED_PATH}.bak_import_{datetime.datetime.now().strftime("%Y%m%d_%H%M%S")}'
    shutil.copy2(SEED_PATH, bk)
    print(f'Backup → {bk}\n')

    data = load_seed()
    sense_map = {s['sense_id']: s for s in data['senses']}
    vocab_map = {v['surface_id']: v for v in data['vocabulary']}

    # Index existing sentences: sense_id + difficulty → list of text_en
    existing = {}
    for s in data['sentences']:
        key = ((s.get('sense_ids') or [None])[0], s.get('difficulty'))
        existing.setdefault(key, []).append(s['text_en'])

    existing_ids = {s['sentence_id'] for s in data['sentences']}
    injected = 0
    skipped_filter = 0
    skipped_validation = 0
    skipped_duplicate = 0
    total = len(llm_sentences)

    for i, item in enumerate(llm_sentences, 1):
        sid        = item.get('sense_id')
        difficulty = item.get('difficulty', 'simple')
        text_en    = item.get('text_en', '').strip()

        if not sid or not text_en:
            continue

        sense = sense_map.get(sid)
        if not sense:
            print(f'  ⚠️  Unknown sense_id: {sid}')
            continue

        surf    = sense.get('surface_id', '')
        vocab   = vocab_map.get(surf, {})
        word_lu = vocab.get('word_lu', surf).rstrip('-')

        print(f'[{i:>3}/{total}] {sid}/{difficulty} — translating…', end='\r', flush=True)

        # Check duplicate
        if text_en in existing.get((sid, difficulty), []):
            skipped_duplicate += 1
            print(f'[{i:>3}/{total}] {sid}/{difficulty} — duplicate, skipped      ')
            continue

        # Filter A
        if not filter_a(text_en, difficulty, sid):
            print(f'[{i:>3}/{total}] {sid}/{difficulty} ✗ Filter A (will): {text_en}')
            skipped_filter += 1
            continue

        # Translate with B+C filters
        text_lu = translate_with_retry(text_en, difficulty, word_lu, sense)
        if not text_lu:
            print(f'[{i:>3}/{total}] {sid}/{difficulty} ✗ LuxMT fail / Filter C: {text_en}')
            skipped_validation += 1
            continue

        # Validate word presence
        if not word_present(text_lu, word_lu, sense):
            print(f'[{i:>3}/{total}] {sid}/{difficulty} ✗ "{word_lu}" absent: {text_en} → {text_lu}')
            skipped_validation += 1
            continue

        # Build sentence ID
        count = len(existing.get((sid, difficulty), [])) + 1
        suffix = f'{difficulty}{count}' if difficulty != 'simple' or count > 1 else difficulty
        sent_id = f'sent_{sid}_{suffix}'
        while sent_id in existing_ids:
            count += 1
            suffix = f'{difficulty}{count}'
            sent_id = f'sent_{sid}_{suffix}'
        existing_ids.add(sent_id)

        data['sentences'].append({
            'sentence_id': sent_id,
            'sense_ids':   [sid],
            'text_en':     text_en,
            'text_lu':     text_lu,
            'cloze_index': 0,   # fixed by annotate_sentences.py
            'audio_url':   '',
            'difficulty':  difficulty,
        })
        existing.setdefault((sid, difficulty), []).append(text_en)
        injected += 1
        print(f'[{i:>3}/{total}] {sid}/{difficulty} ✅ {text_en}')
        print(f'          → {text_lu}')

    old_ver = data.get('version', 0)
    data['version'] = round(float(old_ver) + 0.1, 1)
    save_seed(data)

    print(f'\n✅  Done.')
    print(f'   Injected    : {injected}')
    print(f'   Filter A    : {skipped_filter} rejected (future tense in simple)')
    print(f'   Filter B/C  : {skipped_validation} rejected (LuxMT complexity / word absent)')
    print(f'   Duplicates  : {skipped_duplicate} skipped')
    print(f'   Seed version: {old_ver} → {data["version"]}')
    print(f'\nNext: run  python3 annotate_sentences.py  to fix cloze indices.')


if __name__ == '__main__':
    main()
