#!/usr/bin/env python3
"""
deepl_verify.py — Cross-check LuxMT Luxembourgish sentences against DeepL.

For each sentence: translates text_en → LB via DeepL, then compares the result
with the stored LuxMT text_lu using BOTH character similarity and word-level diff.

Word-level diff catches inflection errors (e.g. "grousse" vs "grouss") that
character similarity would score highly and miss.

Usage:
    pip install deepl
    export DEEPL_API_KEY="your-key-here"
    python3 deepl_verify.py

    # Only check sentences for specific sense IDs:
    python3 deepl_verify.py --sense s_grouss_1 s_kleng_1

    # Set a custom similarity threshold (default 0.72):
    python3 deepl_verify.py --threshold 0.65

Output:
    LuxMT/deepl_cache.json        — cached DeepL translations (avoids re-billing)
    LuxMT/deepl_report.json       — full flagged results, sorted worst-first
    LuxMT/deepl_report.txt        — human-readable version for easy review
"""

import json, os, sys, time, re, argparse
from difflib import SequenceMatcher

SEED_PATH  = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
CACHE_PATH = 'LuxMT/deepl_cache.json'
REPORT_JSON = 'LuxMT/deepl_report.json'
REPORT_TXT  = 'LuxMT/deepl_report.txt'

DEFAULT_THRESHOLD = 0.72   # char similarity below this → flagged
WORD_DIFF_THRESHOLD = 0.60 # word-level Jaccard below this → also flagged

# ── helpers ──────────────────────────────────────────────────────────────────

def char_sim(a, b):
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

def tokenise(text):
    """Lowercase, strip punctuation, return word list."""
    return re.findall(r"[a-zäëöüéàâêîôûùèæœÿA-ZÄËÖÜÉÀÂÊÎÔÛÙÈÆŒŸ]+", text.lower())

def word_jaccard(a, b):
    sa, sb = set(tokenise(a)), set(tokenise(b))
    if not sa and not sb:
        return 1.0
    return len(sa & sb) / len(sa | sb)

def word_diff(a, b):
    """Return words in luxmt_lb not in deepl_lb, and vice-versa."""
    ta, tb = set(tokenise(a)), set(tokenise(b))
    return sorted(ta - tb), sorted(tb - ta)

def load_json(path, default):
    if os.path.exists(path):
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    return default

def save_json(path, obj):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)

# ── main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--threshold', type=float, default=DEFAULT_THRESHOLD)
    parser.add_argument('--sense', nargs='*', help='Limit to these sense_ids')
    parser.add_argument('--limit', type=int, help='Only process first N sentences')
    args = parser.parse_args()

    api_key = os.environ.get('DEEPL_API_KEY')
    if not api_key:
        print("ERROR: Set DEEPL_API_KEY environment variable first.")
        print("  export DEEPL_API_KEY='your-key-here'")
        sys.exit(1)

    try:
        import deepl as deepl_lib
    except ImportError:
        print("ERROR: Run 'pip install deepl' first.")
        sys.exit(1)

    client = deepl_lib.DeepLClient(api_key)

    # Check remaining quota
    usage = client.get_usage()
    print(f"DeepL quota: {usage.character.count:,} / {usage.character.limit:,} chars used "
          f"({100*usage.character.count/usage.character.limit:.1f}%)")

    data = load_json(SEED_PATH, {})
    sentences = data.get('sentences', [])
    cache = load_json(CACHE_PATH, {})

    # Optional filters
    target_senses = set(args.sense) if args.sense else None
    if target_senses:
        sentences = [s for s in sentences
                     if any(sid in target_senses for sid in s.get('sense_ids', []))]
        print(f"Filtered to {len(sentences)} sentences for senses: {target_senses}")
    if args.limit:
        sentences = sentences[:args.limit]

    print(f"Processing {len(sentences)} sentences (cache has {len(cache)} entries)...\n")

    flagged = []
    matched = 0
    errors  = 0

    for i, sent in enumerate(sentences):
        en  = sent.get('text_en', '').strip()
        lu  = sent.get('text_lu', '').strip()
        sid = sent.get('sentence_id', f'sent_{i}')

        if not en or not lu:
            continue

        # Use cache to avoid re-billing
        if en in cache:
            deepl_lu = cache[en]
        else:
            try:
                result = client.translate_text(en, target_lang='LB')
                deepl_lu = result.text
                cache[en] = deepl_lu
                time.sleep(0.08)  # ~12 req/s, well within free tier limits
            except Exception as e:
                print(f"  [ERROR] {sid}: {e}")
                errors += 1
                continue

            # Save cache every 100 new translations
            if len(cache) % 100 == 0:
                save_json(CACHE_PATH, cache)

        cs = char_sim(lu, deepl_lu)
        wj = word_jaccard(lu, deepl_lu)
        only_in_luxmt, only_in_deepl = word_diff(lu, deepl_lu)

        flagged_by_char = cs < args.threshold
        flagged_by_word = wj < WORD_DIFF_THRESHOLD

        if flagged_by_char or flagged_by_word:
            flagged.append({
                'sentence_id': sid,
                'sense_ids': sent.get('sense_ids', []),
                'text_en': en,
                'luxmt_lb': lu,
                'deepl_lb': deepl_lu,
                'char_similarity': round(cs, 3),
                'word_jaccard': round(wj, 3),
                'only_in_luxmt': only_in_luxmt,
                'only_in_deepl': only_in_deepl,
                'flag_reason': ('char+word' if flagged_by_char and flagged_by_word
                                else 'char' if flagged_by_char else 'word'),
            })
        else:
            matched += 1

        if (i + 1) % 200 == 0 or i == len(sentences) - 1:
            print(f"  {i+1}/{len(sentences)}  flagged: {len(flagged)}  matched: {matched}")

    save_json(CACHE_PATH, cache)

    # Sort worst first (lowest char similarity)
    flagged.sort(key=lambda x: (x['char_similarity'], x['word_jaccard']))

    report = {
        'total_checked': len(sentences),
        'matched': matched,
        'flagged': len(flagged),
        'errors': errors,
        'char_threshold': args.threshold,
        'word_jaccard_threshold': WORD_DIFF_THRESHOLD,
        'results': flagged,
    }
    save_json(REPORT_JSON, report)

    # Human-readable text report
    with open(REPORT_TXT, 'w', encoding='utf-8') as f:
        f.write(f"DeepL Verification Report\n")
        f.write(f"{'='*60}\n")
        f.write(f"Total checked : {len(sentences)}\n")
        f.write(f"Matched       : {matched}\n")
        f.write(f"Flagged       : {len(flagged)}\n")
        f.write(f"Errors        : {errors}\n\n")

        for r in flagged:
            f.write(f"{'─'*60}\n")
            f.write(f"ID      : {r['sentence_id']}\n")
            f.write(f"Senses  : {', '.join(r['sense_ids'])}\n")
            f.write(f"EN      : {r['text_en']}\n")
            f.write(f"LuxMT   : {r['luxmt_lb']}\n")
            f.write(f"DeepL   : {r['deepl_lb']}\n")
            f.write(f"Sim     : char={r['char_similarity']}  word={r['word_jaccard']}  [{r['flag_reason']}]\n")
            if r['only_in_luxmt']:
                f.write(f"LuxMT only : {' '.join(r['only_in_luxmt'])}\n")
            if r['only_in_deepl']:
                f.write(f"DeepL only : {' '.join(r['only_in_deepl'])}\n")
            f.write('\n')

    print(f"\nDone.")
    print(f"  JSON report : {REPORT_JSON}")
    print(f"  Text report : {REPORT_TXT}")
    print(f"\nTop 5 most divergent sentences:")
    for r in flagged[:5]:
        print(f"  [{r['char_similarity']}] {r['text_en']}")
        print(f"    LuxMT : {r['luxmt_lb']}")
        print(f"    DeepL : {r['deepl_lb']}")

if __name__ == '__main__':
    main()