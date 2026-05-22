#!/usr/bin/env python3
"""
fix_missing_word_sentences.py

Two-pass fix for sentences where the target Luxembourgish word is absent.

PASS 1 (this script):
  - For each bad sentence, translate the English via DeepL (EN→LB).
  - Accept the translation if the target word appears in it.
  - Save failures (where word still absent after DeepL) to needs_review.json.
  - Apply accepted fixes immediately to the seed.

PASS 2 (after human review):
  - Open needs_review.json, paste it into the conversation.
  - Corrections are applied via apply_review.py.

Resumable: progress saved to fix_progress.json after every sense batch.

Usage:
  cd /Users/nv/projects/luxlingo
  source LuxMT/venv/bin/activate
  python3 LuxMT/fix_missing_word_sentences.py
"""

import json, re, os, sys, time
from collections import defaultdict
import deepl

# ── Paths & config ─────────────────────────────────────────────────────────────
SEED_PATH      = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
PROGRESS_PATH  = 'LuxMT/fix_progress.json'
REVIEW_PATH    = 'LuxMT/needs_review.json'
DEEPL_KEY      = os.environ['DEEPL_FREE_API_KEY']   # set in shell: export DEEPL_FREE_API_KEY=<your-key>

# ── Token helpers ──────────────────────────────────────────────────────────────
APOS       = "''ʼ'"
ELISION_RE = re.compile(r'^[dtlDTL][' + APOS + r']')

def normalize(tok):
    tok = re.sub(r"""[.,?!:;\"()\[\]«»…–\d''""ʼ']""", '', tok)
    return tok.lower()

def find_lemma_idx(lemma_l, text):
    no_n = lemma_l[:-1] if lemma_l.endswith('n') else lemma_l
    for i, w in enumerate(text.split()):
        n = normalize(w)
        if ELISION_RE.match(w) and len(n) > 1:
            n = n[1:]
        if n == lemma_l or n == no_n:
            return i
    return None

def word_present(lemma_l, text):
    return find_lemma_idx(lemma_l, text) is not None

def make_result(lemma_l, lu, text_en, diff):
    idx = find_lemma_idx(lemma_l, lu)
    words = lu.split()
    tok = words[idx] if idx is not None and idx < len(words) else ''
    norm_match = normalize(tok)
    if ELISION_RE.match(tok) and len(norm_match) > 1:
        norm_match = norm_match[1:]
    is_exact = (norm_match == lemma_l)
    return {
        'text_lu':          lu,
        'text_en':          text_en,
        'difficulty':       diff,
        'cloze_index':      idx,
        'exact_form':       is_exact,
        'cloze_confidence': 'exact' if is_exact else 'fallback',
    }

# ── POS guard ──────────────────────────────────────────────────────────────────
def is_skippable(pos, lemma):
    if pos.startswith('VRB') or pos.startswith('AUX') or pos.startswith('VERB'):
        return True
    if lemma.endswith('-'):
        return True
    if pos == 'NP' and ' ' in lemma:
        return True
    return False

# ── DeepL ─────────────────────────────────────────────────────────────────────
_deepl = deepl.DeepLClient(DEEPL_KEY)

def deepl_translate(text_en):
    for attempt in range(3):
        try:
            result = _deepl.translate_text(text_en, target_lang='LB')
            lb = result.text.strip()
            return lb if lb else None
        except Exception as e:
            if attempt == 2:
                print(f'    DeepL error: {e}')
            time.sleep(1.0 * (attempt + 1))
    return None

# ── Seed helpers ───────────────────────────────────────────────────────────────
def load_seed():
    with open(SEED_PATH, encoding='utf-8') as f:
        return json.load(f)

def save_seed(data):
    data['version'] = round(data.get('version', 7.0) + 0.1, 1)
    with open(SEED_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f'  Seed saved v{data["version"]}')

def apply_replacements(data, replacements):
    updated = 0
    for sent in data['sentences']:
        r = replacements.get(sent['sentence_id'])
        if r:
            sent['text_lu']          = r['text_lu']
            sent['text_en']          = r['text_en']
            sent['cloze_index']      = r['cloze_index']
            sent['exact_form']       = r['exact_form']
            sent['cloze_confidence'] = r['cloze_confidence']
            sent.pop('n_rule_form', None)
            sent.pop('n_rule_word_index', None)
            updated += 1
    return updated

# ── Build bad-sentence index ───────────────────────────────────────────────────
def build_bad_index(data, sense_map):
    bad = defaultdict(list)
    for sent in data['sentences']:
        if sent.get('cloze_confidence') == 'nrule':
            continue
        text = sent['text_lu']
        done = False
        for sid in sent.get('sense_ids', []):
            if done: break
            info    = sense_map.get(sid, {})
            lemma_l = info.get('lemma_l', '')
            pos     = info.get('pos', '')
            lemma   = info.get('lemma', '')
            if is_skippable(pos, lemma) or not lemma_l or len(lemma_l) < 2:
                continue
            if find_lemma_idx(lemma_l, text) is None:
                no_n = lemma_l[:-1] if lemma_l.endswith('n') else lemma_l
                in_compound = any(lemma_l in normalize(w) or no_n in normalize(w)
                                  for w in text.split())
                if not in_compound:
                    bad[sid].append(sent)
                    done = True
    return bad

# ── Progress helpers ───────────────────────────────────────────────────────────
def load_progress():
    if os.path.exists(PROGRESS_PATH):
        with open(PROGRESS_PATH, encoding='utf-8') as f:
            return json.load(f)
    return {'done_senses': [], 'replacements': {}}

def save_progress(p):
    with open(PROGRESS_PATH, 'w', encoding='utf-8') as f:
        json.dump(p, f, ensure_ascii=False, indent=2)

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    print('Loading seed…')
    data = load_seed()

    surface_to_word = {v['surface_id']: v['word_lu'] for v in data['vocabulary']}
    sense_map = {}
    for s in data['senses']:
        w = surface_to_word.get(s['surface_id'], '')
        sense_map[s['sense_id']] = {
            'lemma':      w,
            'lemma_l':    w.lower(),
            'pos':        s.get('pos', ''),
            'primary_en': s.get('primary_en', ''),
        }

    bad   = build_bad_index(data, sense_map)
    total = sum(len(v) for v in bad.values())
    print(f'Bad sentences (non-verb, word absent): {total} across {len(bad)} senses.')

    # Show DeepL quota
    try:
        usage = _deepl.get_usage()
        print(f'DeepL quota: {usage.character.count:,} / {usage.character.limit:,} chars used')
    except Exception:
        pass

    progress     = load_progress()
    done_senses  = set(progress['done_senses'])
    replacements = progress.get('replacements', {})

    todo = [(sid, sents) for sid, sents in bad.items() if sid not in done_senses]
    print(f'Already done: {len(done_senses)}. Remaining: {len(todo)} senses.\n')

    needs_review = []   # sentences where DeepL still didn't include the word
    fixed_count  = 0
    failed_count = 0

    for i, (sense_id, bad_sents) in enumerate(todo):
        info       = sense_map[sense_id]
        word_lu    = info['lemma']
        lemma_l    = info['lemma_l']
        primary_en = info['primary_en']
        pos        = info['pos']

        print(f'[{i+1}/{len(todo)}] "{word_lu}" ({primary_en}) — {len(bad_sents)} sentences', end='', flush=True)

        for sent in bad_sents:
            text_en = sent['text_en']
            diff    = sent.get('difficulty', 'simple')
            sid_s   = sent['sentence_id']

            lu = deepl_translate(text_en)

            if lu and word_present(lemma_l, lu):
                # DeepL got it right
                replacements[sid_s] = make_result(lemma_l, lu, text_en, diff)
                fixed_count += 1
                print('.', end='', flush=True)
            else:
                # DeepL used a synonym — queue for human/Claude review
                needs_review.append({
                    'sentence_id': sid_s,
                    'sense_id':    sense_id,
                    'word_lu':     word_lu,
                    'primary_en':  primary_en,
                    'pos':         pos,
                    'difficulty':  diff,
                    'text_en':     text_en,
                    'deepl_lu':    lu or '',    # what DeepL gave (might be useful context)
                    'text_lu':     '',          # to be filled in by reviewer
                    'cloze_index': -1,
                })
                failed_count += 1
                print('?', end='', flush=True)

            time.sleep(0.15)   # gentle rate limit

        print()  # newline after dots

        done_senses.add(sense_id)
        progress['done_senses']  = list(done_senses)
        progress['replacements'] = replacements
        save_progress(progress)

    # Apply accepted fixes to seed
    print(f'\nDeepL fixed:        {fixed_count}')
    print(f'Needs review:       {failed_count}')
    print(f'\nApplying {len(replacements)} DeepL fixes to seed…')
    data    = load_seed()
    updated = apply_replacements(data, replacements)
    save_seed(data)

    # Save review queue
    if needs_review:
        # Load any existing review items (from previous run) and merge
        existing_review = []
        if os.path.exists(REVIEW_PATH):
            with open(REVIEW_PATH, encoding='utf-8') as f:
                existing_review = json.load(f)
            existing_ids = {r['sentence_id'] for r in existing_review}
            needs_review = existing_review + [r for r in needs_review
                                              if r['sentence_id'] not in existing_ids]

        with open(REVIEW_PATH, 'w', encoding='utf-8') as f:
            json.dump(needs_review, f, ensure_ascii=False, indent=2)
        print(f'\n{len(needs_review)} sentences saved to {REVIEW_PATH}')
        print('Next step: paste needs_review.json into the conversation for correction.')
    else:
        print('\nAll sentences fixed by DeepL — no review needed!')
        if os.path.exists(PROGRESS_PATH):
            os.remove(PROGRESS_PATH)

    print(f'\nUpdated {updated} sentences in seed.')

if __name__ == '__main__':
    main()
