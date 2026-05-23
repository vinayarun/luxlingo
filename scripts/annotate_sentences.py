#!/usr/bin/env python3
"""
Annotate sentences in initial_seed.json with:
  1. cloze_index  — corrected using paradigm data (present + past_participle)
  2. n_rule_word_index + n_rule_form — detected via Eifeler Regel

Run after seed_paradigms.py and expand_sentences.py.
Safe to re-run: overwrites existing annotations.
"""

import json, re, shutil, datetime

SEED_PATH = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
PUNCT     = str.maketrans('', '', '.,!?;:\'"„"«»')

# Eifeler Regel: drop 'n' before consonants NOT in this set
UNITED_ZOHA = set('unitedzoahUNITEDZOAH')

# Words known to be subject to the n-rule (ends in n in their full form)
N_RULE_LEMMAS = {
    'den', 'een', 'vun', 'an', 'wann', 'keen', 'hien', 'sinn', 'hunn',
    'kënnen', 'wëllen', 'mussen', 'duerfen', 'sollen', 'kommen', 'goen',
    'maachen', 'gesinn', 'ginn', 'bleiwen', 'bréngen', 'fannen', 'loossen',
    'iessen', 'drénken', 'léieren', 'schreiwen', 'liesen', 'schwätzen',
    'verstoen', 'wëssen', 'denken', 'gleewen', 'héieren', 'sichen',
    'weisen', 'kafen', 'verkafen', 'bezuelen', 'lafen', 'huelen', 'halen',
    'meng', 'deng', 'seng', 'eisen', 'äeren',
    'mengem', 'dengem', 'sengem', 'engem',
    'een', 'kee', 'wéi', 'wann', 'dann', 'mann', 'kan', 'ween',
}


def clean(word):
    return word.translate(PUNCT).lower()


def first_letter(word):
    """Return first alphabetic character of a word."""
    for c in word:
        if c.isalpha():
            return c
    return ''


def n_rule_drops(word_clean, next_word_clean):
    """Return True if 'word' should drop its final 'n' before 'next_word'."""
    if not word_clean.endswith('n'):
        return False
    fl = first_letter(next_word_clean)
    if not fl:
        return True   # end of sentence / punctuation — drop
    return fl.lower() not in UNITED_ZOHA


def all_paradigm_forms(sense):
    """Return a flat set of verb form strings for matching."""
    forms = set()
    paradigm = sense.get('paradigm', {})
    for row in paradigm.get('present', []):
        # row like "ech maachen" or "hien/si/et ass" — take last token
        parts = row.split()
        verb = parts[-1] if parts else ''
        if verb and verb != '?':
            forms.add(verb.lower())
    pp = paradigm.get('past_participle', '')
    if pp:
        forms.add(pp.lower())
    return forms


def find_cloze_index(words_clean, lemma, paradigm_forms, current_index):
    """
    Try (in order):
      1. Exact lemma match
      2. Any paradigm form match
      3. N-rule form: lemma with final 'n' dropped (e.g. "an" → "a", "den" → "de")
      4. Prefix match (first 3 chars of lemma)
      5. Keep current_index as fallback
    Returns (index, confidence) where confidence is
      'exact' | 'paradigm' | 'nrule' | 'prefix' | 'fallback'
    """
    # 1. Exact lemma
    for i, w in enumerate(words_clean):
        if w == lemma:
            return i, 'exact'

    # 2. Paradigm form
    for i, w in enumerate(words_clean):
        if w in paradigm_forms:
            return i, 'paradigm'

    # 3. N-rule form (lemma ends in 'n', try with n dropped)
    if lemma.endswith('n') and len(lemma) > 1:
        nrule_form = lemma[:-1]
        for i, w in enumerate(words_clean):
            if w == nrule_form:
                return i, 'nrule'

    # 4. Prefix (≥3 chars)
    if len(lemma) >= 3:
        prefix = lemma[:3]
        for i, w in enumerate(words_clean):
            if w.startswith(prefix) and w != lemma:
                return i, 'prefix'

    # 5. Fallback
    return current_index, 'fallback'


def annotate_n_rule(words_clean):
    """
    Walk sentence words, return (word_index, dropped_form) for the first
    n-rule application, or (None, None) if none.
    """
    for i, w in enumerate(words_clean):
        if not w.endswith('n'):
            continue
        # Check if this word is a known n-rule candidate or ends in common pattern
        is_candidate = (
            w in N_RULE_LEMMAS or
            w.endswith('en') or
            w.endswith('an') or
            w.endswith('in') or
            w.endswith('on') or
            w.endswith('nn')
        )
        if not is_candidate:
            continue
        next_w = words_clean[i + 1] if i + 1 < len(words_clean) else ''
        if n_rule_drops(w, next_w):
            # The form in the sentence already has the n dropped
            # Store what the form *with* n would be — but we detect if form *without* n is what's there
            # Actually we annotate: this word at index i has had its n dropped → form = w (already dropped)
            return i, w
    return None, None


def main():
    bk = f'{SEED_PATH}.bak_annotate_{datetime.datetime.now().strftime("%Y%m%d_%H%M%S")}'
    shutil.copy2(SEED_PATH, bk)
    print(f'Backup → {bk}\n')

    with open(SEED_PATH, encoding='utf-8') as f:
        data = json.load(f)

    sense_map = {s['sense_id']: s for s in data['senses']}
    vocab_map = {v['surface_id']: v for v in data['vocabulary']}

    stats = {'exact': 0, 'paradigm': 0, 'nrule': 0, 'prefix': 0, 'fallback': 0,
             'n_rule': 0, 'unchanged': 0}

    for sent in data['sentences']:
        primary_sid = (sent.get('sense_ids') or [None])[0]
        sense = sense_map.get(primary_sid, {}) if primary_sid else {}
        surf  = sense.get('surface_id', '')
        vocab = vocab_map.get(surf, {})
        lemma = vocab.get('word_lu', '').rstrip('-').lower().translate(PUNCT)

        raw_words   = sent.get('text_lu', '').split()
        words_clean = [clean(w) for w in raw_words]

        # ── 1. Correct cloze_index ────────────────────────────────────────
        paradigm_forms = all_paradigm_forms(sense)
        old_idx = sent.get('cloze_index', 0)

        if lemma:
            new_idx, confidence = find_cloze_index(
                words_clean, lemma, paradigm_forms, old_idx
            )
        else:
            new_idx, confidence = old_idx, 'fallback'

        # Clamp to valid range
        new_idx = max(0, min(new_idx, len(words_clean) - 1)) if words_clean else 0

        sent['cloze_index'] = new_idx
        sent['cloze_confidence'] = confidence
        # exact_form = True when lemma appears unchanged — no conjugation, no n-rule
        sent['exact_form'] = (confidence == 'exact')
        stats[confidence] += 1

        # ── 2. Annotate n-rule ────────────────────────────────────────────
        # If cloze found via 'nrule' confidence, the word is already in its n-dropped form.
        if confidence == 'nrule':
            sent['n_rule_word_index'] = new_idx
            sent['n_rule_form'] = words_clean[new_idx] if words_clean else ''
            stats['n_rule'] += 1
        else:
            # Also check if cloze word ends in n and next word triggers the rule
            cloze_word = words_clean[new_idx] if words_clean and new_idx < len(words_clean) else ''
            next_word  = words_clean[new_idx + 1] if new_idx + 1 < len(words_clean) else ''
            if cloze_word and n_rule_drops(cloze_word + 'n', next_word):
                full_form = cloze_word + 'n'
                if (full_form in N_RULE_LEMMAS or full_form in paradigm_forms or
                        (lemma.endswith('n') and cloze_word == lemma[:-1])):
                    sent['n_rule_word_index'] = new_idx
                    sent['n_rule_form'] = cloze_word
                    stats['n_rule'] += 1
                else:
                    sent.pop('n_rule_word_index', None)
                    sent.pop('n_rule_form', None)
            else:
                sent.pop('n_rule_word_index', None)
                sent.pop('n_rule_form', None)

    old_ver      = data.get('version', 0)
    data['version'] = round(float(old_ver) + 0.1, 1)

    with open(SEED_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f'\n✅  Annotation complete.')
    print(f'   Cloze — exact: {stats["exact"]}, paradigm: {stats["paradigm"]}, '
          f'nrule: {stats["nrule"]}, prefix: {stats["prefix"]}, fallback: {stats["fallback"]}')
    print(f'   N-rule annotations: {stats["n_rule"]}')
    print(f'   Seed version: {old_ver} → {data["version"]}')


if __name__ == '__main__':
    main()
