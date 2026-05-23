#!/usr/bin/env python3
"""
Generate simple-difficulty sentences per sense.

Hybrid approach:
  - Simple POS (PREP, ADJ, SUBST, CONJ, ADV, PRON, ART, numbers):
      Pure template substitution — no LLM, fast and deterministic.
  - Complex POS (VRB, VRB+MOD, VRBPART):
      Claude generates 12 English variations in one call.
  LuxMT translation runs in parallel (ThreadPoolExecutor).
  Validation: target word (lemma, n-rule form, or paradigm verb form) must
  appear in the Luxembourgish output before a sentence is accepted.

Resumable via STATE_PATH.
"""

import json, re, time, os, shutil, datetime, itertools, subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

SEED_PATH    = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
STATE_PATH   = 'LuxMT/expand_sentences_state.json'
LUXMT_URL    = 'https://luxasr.uni.lu/luxmt/translate'
TARGET_SIMPLE    = 3
LUXMT_WORKERS    = 6   # parallel LuxMT requests
CLAUDE_BATCH     = 12  # sentences Claude generates per call
PUNCT = str.maketrans('', '', '.,!?;:\'"„"«»()[]')

RATE_LIMIT_MARKERS = [
    "you've hit your limit", "rate limit", "resets", "europe/luxembourg",
    "try again later", "overloaded",
]

# ── Template banks (used for non-verb POS) ────────────────────────────────────

OBJECTS  = ['a book','a pen','a ball','a key','a bag','a cup','a flower',
            'an apple','a cookie','a glass of water','a letter','a gift',
            'a cake','a newspaper','a pencil','a toy']
PLACES   = ['the house','the school','the room','the kitchen','the car',
            'the garden','the city','the park','the office','the market',
            'the library','the street','the village','the forest']
PERSONS  = ['my mother','my father','my friend','my sister','my brother',
            'the teacher','the child','the man','the woman','my neighbour']
TIMES    = ['every day','every morning','every evening','now','today',
            'tomorrow','always','often','sometimes','at noon']

TEMPLATES = {
    'PREP': [
        '[WORD] [PLACE].', 'I am [WORD] [PLACE].', 'The cat is [WORD] [PLACE].',
        'We sit [WORD] [PLACE].', 'The book is [WORD] [PLACE].',
        '[PERSON] is [WORD] [PLACE].', 'I work [WORD] [PLACE].',
        'She lives [WORD] [PLACE].', 'He plays [WORD] [PLACE].',
        'The dog is [WORD] [PLACE].', 'We eat [WORD] [PLACE].',
        'They sleep [WORD] [PLACE].',
    ],
    'SUBST': [
        'I have a [WORD].', 'The [WORD] is here.', 'Where is the [WORD]?',
        'I see a [WORD].', 'This [WORD] is big.', 'Give me the [WORD].',
        'I like the [WORD].', 'The [WORD] is on the table.',
        'I need a [WORD].', 'She has a [WORD].', 'He wants a [WORD].',
        'The [WORD] is good.',
    ],
    'ADJ': [
        'The house is [WORD].', 'My dog is [WORD].', 'This book is [WORD].',
        'The water is [WORD].', 'Her cat is [WORD].', 'This car is [WORD].',
        'The food is [WORD].', 'The room is [WORD].', 'My mother is [WORD].',
        'The garden is [WORD].', 'The school is [WORD].', 'This apple is [WORD].',
    ],
    'ADV': [
        'I [WORD] drink water.', 'She [WORD] reads books.',
        'He [WORD] goes to school.', 'They [WORD] play here.',
        'We [WORD] eat lunch.', 'I [WORD] wake up early.',
        'She [WORD] helps me.', 'He [WORD] comes home.',
        'I am [WORD] here.', 'She is [WORD] happy.',
        'We are [WORD] tired.', 'He is [WORD] ready.',
    ],
    'PRON': [
        '[WORD] am here.', '[WORD] is my friend.', '[WORD] likes coffee.',
        'I see [WORD].', 'I help [WORD].', 'I give [WORD] a book.',
        'I give [WORD] water.', 'She gives [WORD] a pen.',
        '[WORD] reads every day.', '[WORD] goes to school.',
        '[WORD] has a dog.', '[WORD] is happy.',
    ],
    'CONJ': [
        'Tea [WORD] coffee.', 'Bread [WORD] butter.', 'You [WORD] I.',
        'Coffee [WORD] milk.', 'A dog [WORD] a cat.', 'He [WORD] she.',
        'Water [WORD] juice.', 'A book [WORD] a pen.',
        'Mother [WORD] father.', 'School [WORD] home.',
        'Big [WORD] small.', 'Happy [WORD] sad.',
    ],
    'PART': [
        'That is [WORD] correct.', 'It is [WORD] easy.',
        'This is [WORD] my book.', 'She is [WORD] tired.',
        'He is [WORD] here.', 'I am [WORD] happy.',
        'That is [WORD] a dog.', 'It is [WORD] cold.',
        'This is [WORD] right.', 'She is [WORD] wrong.',
        'He is [WORD] old.', 'This is [WORD] a school.',
    ],
}

def template_key(pos):
    p = pos.upper()
    if p.startswith('VRB') or p in ('VERB',): return None   # → Claude
    if p.startswith('SUBST') or 'NB' in p:   return 'SUBST'
    if p.startswith('ADJ'):                   return 'ADJ'
    if p.startswith('ADV'):                   return 'ADV'
    if p.startswith('PRON'):                  return 'PRON'
    if p.startswith('PREP'):                  return 'PREP'
    if p.startswith('CONJ'):                  return 'CONJ'
    if p.startswith('PART') or p.startswith('ART'): return 'PART'
    return 'SUBST'

def template_candidates(word_en, pos, existing_en):
    key = template_key(pos)
    if key is None:
        return None   # signal to use Claude
    bank = TEMPLATES[key]
    obj_c, place_c, person_c, time_c = (
        itertools.cycle(OBJECTS), itertools.cycle(PLACES),
        itertools.cycle(PERSONS), itertools.cycle(TIMES),
    )
    out = []
    for tmpl in bank:
        s = (tmpl.replace('[WORD]', word_en)
                 .replace('[OBJ]',    next(obj_c))
                 .replace('[PLACE]',  next(place_c))
                 .replace('[PERSON]', next(person_c))
                 .replace('[TIME]',   next(time_c)))
        if s not in existing_en:
            out.append(s)
    return out


# ── Claude (verbs only) ───────────────────────────────────────────────────────

def is_rate_limit(text):
    low = text.lower()
    return any(m in low for m in RATE_LIMIT_MARKERS)

def claude_candidates(word_en, pos, existing_en, tried_en, retries=3):
    existing_block = '\n'.join(f'  - {s}' for s in (list(existing_en)[:5] + tried_en[:5])) or '  (none)'
    prompt = (
        f'Generate {CLAUDE_BATCH} simple English sentences (A1 level, max 8 words each) '
        f'using the verb "{word_en}" (POS: {pos}).\n\n'
        f'STYLE — vary only the subject/object/time, keep the verb form close to "{word_en}":\n'
        f'  - "I give you a book."  "I give you a pen."  "She gives him a gift."\n\n'
        f'RULES:\n'
        f'  - "{word_en}" or its direct inflected form MUST appear in every sentence.\n'
        f'  - A1 vocabulary only (house, school, water, dog, book, mother...).\n'
        f'  - Avoid these:\n{existing_block}\n\n'
        f'Return ONLY the {CLAUDE_BATCH} sentences, one per line, no numbering.'
    )
    for attempt in range(retries):
        try:
            r = subprocess.run(['claude', '-p', prompt],
                               capture_output=True, text=True, timeout=60)
            out = r.stdout.strip()
            if is_rate_limit(out):
                wait = 60 * (attempt + 1)
                print(f'    ⏳ Rate limit — waiting {wait}s')
                time.sleep(wait)
                continue
            lines = [re.sub(r'^[\d\.\-\*\)]\s*', '', l.strip())
                     for l in out.splitlines() if l.strip()]
            valid = [l for l in lines if l and not is_rate_limit(l)]
            if valid:
                return valid[:CLAUDE_BATCH]
        except Exception as e:
            print(f'    claude error (attempt {attempt+1}): {e}')
            time.sleep(10)
    return []


# ── LuxMT (parallel) ──────────────────────────────────────────────────────────

def _translate_one(text_en):
    for attempt in range(2):
        try:
            resp = requests.post(
                LUXMT_URL,
                json={'text': text_en, 'source_lang': 'en', 'target_lang': 'lb'},
                timeout=15,
            )
            if resp.status_code == 200:
                return text_en, resp.json().get('translated_text')
        except Exception:
            time.sleep(2)
    return text_en, None

def translate_batch(sentences_en):
    """Translate a list of English sentences to Luxembourgish in parallel."""
    results = {}
    with ThreadPoolExecutor(max_workers=LUXMT_WORKERS) as pool:
        futures = {pool.submit(_translate_one, s): s for s in sentences_en}
        for future in as_completed(futures):
            en, lu = future.result()
            results[en] = lu
    return results


# ── Validation ────────────────────────────────────────────────────────────────

def clean(word):
    return word.translate(PUNCT).lower()

def paradigm_forms(sense):
    forms = set()
    for row in sense.get('paradigm', {}).get('present', []):
        parts = row.split()
        if parts:
            forms.add(parts[-1].lower())
    pp = sense.get('paradigm', {}).get('past_participle', '')
    if pp:
        forms.add(pp.lower())
    return forms

def word_present(text_lu, lemma, sense):
    words = [clean(w) for w in text_lu.split()]
    lc = clean(lemma)
    if lc in words:
        return True
    if lc.endswith('n') and len(lc) > 1 and lc[:-1] in words:
        return True
    for f in paradigm_forms(sense):
        if f in words:
            return True
    return False


# ── I/O ───────────────────────────────────────────────────────────────────────

def load_seed():
    with open(SEED_PATH, encoding='utf-8') as f:
        return json.load(f)

def save_seed(data):
    with open(SEED_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def load_state():
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH, encoding='utf-8') as f:
            return json.load(f)
    return {'done_sids': [], 'new_sentences': []}

def save_state(state):
    with open(STATE_PATH, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    bk = f'{SEED_PATH}.bak_{datetime.datetime.now().strftime("%Y%m%d_%H%M%S")}'
    shutil.copy2(SEED_PATH, bk)
    print(f'Backup → {bk}\n')

    data  = load_seed()
    state = load_state()

    vocab_map = {v['surface_id']: v for v in data['vocabulary']}

    simple_count       = {}
    existing_en_by_sid = {}
    for s in data['sentences']:
        primary = (s.get('sense_ids') or [None])[0]
        if not primary:
            continue
        if s.get('difficulty') == 'simple':
            simple_count[primary] = simple_count.get(primary, 0) + 1
        existing_en_by_sid.setdefault(primary, []).append(s['text_en'])

    seen, senses_todo = set(), []
    for sense in data['senses']:
        sid = sense['sense_id']
        if sid in seen or sid in state['done_sids']:
            continue
        seen.add(sid)
        if simple_count.get(sid, 0) < TARGET_SIMPLE:
            senses_todo.append(sense)

    print(f'Senses needing more sentences : {len(senses_todo)}')
    verb_count = sum(1 for s in senses_todo if template_key(s.get('pos','')) is None)
    print(f'  → Templates (no LLM) : {len(senses_todo) - verb_count}')
    print(f'  → Claude (verbs)     : {verb_count}\n')

    new_sentences   = state['new_sentences']
    all_sent_ids    = ({s['sentence_id'] for s in data['sentences']} |
                       {s['sentence_id'] for s in new_sentences})
    existing_en_all = {s['text_en'] for s in data['sentences']}

    for idx, sense in enumerate(senses_todo):
        sid     = sense['sense_id']
        surf    = sense.get('surface_id', '')
        vocab   = vocab_map.get(surf, {})
        word_lu = vocab.get('word_lu', surf).rstrip('-')
        word_en = sense.get('primary_en', sid)
        pos     = sense.get('pos', 'unknown')

        have   = simple_count.get(sid, 0)
        need   = TARGET_SIMPLE - have
        use_llm = template_key(pos) is None
        src    = 'Claude' if use_llm else 'template'
        print(f'[{idx+1}/{len(senses_todo)}] {sid}  "{word_lu}"/{word_en} [{pos}]  '
              f'have={have} need={need}  src={src}')

        existing_en = existing_en_by_sid.get(sid, [])
        tried_en    = []

        # Get English candidates
        if use_llm:
            candidates_en = claude_candidates(word_en, pos, existing_en_all, tried_en)
            tried_en.extend(candidates_en)
        else:
            candidates_en = template_candidates(word_en, pos, existing_en_all) or []

        # Filter already-used
        candidates_en = [c for c in candidates_en
                         if c not in existing_en_all and c not in existing_en]

        # Translate in parallel
        translations = translate_batch(candidates_en)

        # Validate and collect
        collected = []
        for text_en in candidates_en:
            if len(collected) >= need:
                break
            text_lu = translations.get(text_en)
            if not text_lu:
                continue
            if word_present(text_lu, word_lu, sense):
                collected.append((text_en, text_lu))
                existing_en_all.add(text_en)
                print(f'    ✅ EN: {text_en}')
                print(f'       LB: {text_lu}')
            else:
                print(f'    ✗  "{word_lu}" absent | {text_en[:45]} → {text_lu[:45]}')

        # One Claude retry if verb and not enough
        if use_llm and len(collected) < need:
            extra = claude_candidates(word_en, pos, existing_en_all, tried_en)
            extra = [c for c in extra if c not in existing_en_all and c not in tried_en]
            if extra:
                more = translate_batch(extra)
                for text_en in extra:
                    if len(collected) >= need:
                        break
                    text_lu = more.get(text_en)
                    if text_lu and word_present(text_lu, word_lu, sense):
                        collected.append((text_en, text_lu))
                        existing_en_all.add(text_en)
                        print(f'    ✅ (retry) LB: {text_lu}')

        if len(collected) < need:
            print(f'  ⚠️  {len(collected)}/{need} valid for "{word_lu}"')
        else:
            print(f'  ✓  {len(collected)}/{need}')

        current_simple = have
        for j, (text_en, text_lu) in enumerate(collected):
            n_idx   = current_simple + j + 1
            sent_id = f'sent_{sid}_simple{n_idx}'
            if sent_id in all_sent_ids:
                sent_id = f'sent_{sid}_simple{n_idx}b'
            all_sent_ids.add(sent_id)
            new_sentences.append({
                'sentence_id': sent_id,
                'sense_ids':   [sid],
                'text_en':     text_en,
                'text_lu':     text_lu,
                'cloze_index': 0,
                'audio_url':   '',
                'difficulty':  'simple',
            })

        state['done_sids'].append(sid)
        state['new_sentences'] = new_sentences

        if (idx + 1) % 20 == 0:
            save_state(state)
            print(f'  — state saved ({idx+1} done) —\n')

        time.sleep(0.05)

    # Inject into seed
    seed_ids = {s['sentence_id'] for s in data['sentences']}
    injected = 0
    for s in new_sentences:
        if s['sentence_id'] not in seed_ids:
            data['sentences'].append(s)
            injected += 1

    old_ver = data.get('version', 0)
    data['version'] = round(float(old_ver) + 0.1, 1)
    save_seed(data)
    save_state(state)

    print(f'\n✅  Done.')
    print(f'   Sentences injected : {injected}')
    print(f'   Seed version       : {old_ver} → {data["version"]}')
    print(f'\nNext: run  python3 annotate_sentences.py  to fix cloze indices.')


if __name__ == '__main__':
    main()
