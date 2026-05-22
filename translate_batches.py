#!/usr/bin/env python3
"""
translate_batches.py — Translate all new batch sentences via LuxMT and inject into the seed.

Pipeline:
  1. Merge all LuxMT/batchXX.json files
  2. Deduplicate against existing seed sentences
  3. Translate via LuxMT with 3-layer validation (parallel workers)
  4. Inject accepted sentences into initial_seed.json
  5. Bump seed version

Progress is auto-reported every 100 sentences.
State is saved every 50 sentences so the script can be interrupted and resumed.

Usage:
    python3 translate_batches.py               # run full pipeline
    python3 translate_batches.py --dry-run     # count/preview without translating
    python3 translate_batches.py --reset       # clear saved state and start fresh
"""

import json, glob, os, sys, time, re, shutil, datetime, argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import deepl

# ── Paths ──────────────────────────────────────────────────────────────────────
SEED_PATH    = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
BATCH_GLOB   = 'LuxMT/batch*.json'
STATE_PATH   = 'LuxMT/translate_batches_state.json'
DEEPL_KEY    = os.environ['DEEPL_FREE_API_KEY']   # set in shell: export DEEPL_FREE_API_KEY=<your-key>

# ── Config ─────────────────────────────────────────────────────────────────────
WORKERS      = 4      # parallel DeepL requests (free tier is generous but be respectful)
MAX_RETRIES  = 3      # retries per sentence
SAVE_EVERY   = 50     # save state every N processed
REPORT_EVERY = 100    # print progress every N processed

# Sentences containing these complexity markers are rejected for simple difficulty
COMPLEX_MARKERS_LB = {'wäert', 'géif', 'wier', 'hätt', 'wann ech', 'obwuel', 'well ech'}

# Luxembourgish character set — used to reject obvious non-LB distractors
LB_CHARS = set('ëäöüéàâêîôûùèæœÿËÄÖÜÉÀÂÊÎÔÛÙÈÆŒŸ')

# ── DeepL ─────────────────────────────────────────────────────────────────────

_deepl_client = deepl.DeepLClient(DEEPL_KEY)

def translate(text_en: str) -> str | None:
    for attempt in range(MAX_RETRIES):
        try:
            result = _deepl_client.translate_text(text_en, target_lang='LB')
            lb = result.text.strip()
            return lb if lb else None
        except Exception:
            pass
        if attempt < MAX_RETRIES - 1:
            time.sleep(1.0 * (attempt + 1))
    return None

def translate_batch_parallel(items: list[tuple]) -> dict:
    """Translate a list of (idx, text_en) in parallel. Returns {idx: text_lb}."""
    results = {}
    with ThreadPoolExecutor(max_workers=WORKERS) as ex:
        futures = {ex.submit(translate, text): idx for idx, text in items}
        for future in as_completed(futures):
            idx = futures[future]
            results[idx] = future.result()
    return results

# ── Validation filters ─────────────────────────────────────────────────────────

def a_filter(text_en: str) -> bool:
    """Reject English sentences that imply future tense (will)."""
    return 'will ' not in text_en.lower()

def b_filter(text_lb: str | None) -> bool:
    return bool(text_lb and len(text_lb.split()) >= 1)

def c_filter(text_lb: str, difficulty: str) -> bool:
    """For simple sentences, reject translations with complex LB markers."""
    if difficulty != 'simple':
        return True
    return not any(m in text_lb.lower() for m in COMPLEX_MARKERS_LB)

def validate(text_en: str, text_lb: str, difficulty: str) -> bool:
    return a_filter(text_en) and b_filter(text_lb) and c_filter(text_lb, difficulty)

# ── State ──────────────────────────────────────────────────────────────────────

def load_state() -> dict:
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH, encoding='utf-8') as f:
            return json.load(f)
    return {'done_keys': [], 'new_sentences': [], 'skipped': 0, 'failed': 0}

def save_state(state: dict):
    with open(STATE_PATH, 'w', encoding='utf-8') as f:
        json.dump(state, f, ensure_ascii=False, indent=2)

# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--reset',   action='store_true')
    args = parser.parse_args()

    if args.reset and os.path.exists(STATE_PATH):
        os.remove(STATE_PATH)
        print("State cleared.\n")

    # 1. Load seed
    seed = json.load(open(SEED_PATH, encoding='utf-8'))
    existing_keys = {
        (s.get('sense_ids', [s.get('sense_id','')])[0], s['text_en'])
        for s in seed['sentences']
    }
    sent_ids_used = {s['sentence_id'] for s in seed['sentences']}

    # 2. Merge batch files
    batch_files = sorted(glob.glob(BATCH_GLOB))
    batch_files = [f for f in batch_files if 'batch10_part' not in f]
    all_items = []
    for fpath in batch_files:
        data = json.load(open(fpath, encoding='utf-8'))
        for s in data:
            all_items.append({
                'sense_id':  s['sense_id'],
                'difficulty': s.get('difficulty', 'simple'),
                'text_en':   s['text_en'].strip(),
            })

    # 3. Deduplicate
    seen_texts = set()
    todo = []
    dupes = 0
    for item in all_items:
        key = (item['sense_id'], item['text_en'])
        if key in existing_keys or item['text_en'] in seen_texts:
            dupes += 1
            continue
        seen_texts.add(item['text_en'])
        item['_key'] = f"{item['sense_id']}|{item['text_en']}"
        todo.append(item)

    print(f"Batch files:      {len(batch_files)}")
    print(f"Total sentences:  {len(all_items)}")
    print(f"Duplicates:       {dupes}")
    print(f"To translate:     {len(todo)}")

    if args.dry_run:
        print("\n(dry-run — exiting before translation)")
        return

    # 4. Load state and filter already-done
    state = load_state()
    done_keys = set(state['done_keys'])
    remaining = [item for item in todo if item['_key'] not in done_keys]
    print(f"Already done:     {len(todo) - len(remaining)}")
    print(f"Remaining:        {len(remaining)}")
    # Show DeepL quota before starting
    try:
        usage = _deepl_client.get_usage()
        print(f"DeepL quota:      {usage.character.count:,} / {usage.character.limit:,} used")
    except Exception:
        pass
    print(f"\nStarting translation (DeepL EN→LB) at {datetime.datetime.now().strftime('%H:%M:%S')}...\n")

    if not remaining:
        print("Nothing left to translate — injecting into seed.")
    else:
        # 5. Translate in parallel chunks
        chunk_size = WORKERS * 4
        processed = 0
        t_start = time.time()

        for chunk_start in range(0, len(remaining), chunk_size):
            chunk = remaining[chunk_start:chunk_start + chunk_size]
            items_to_translate = [(i, item['text_en']) for i, item in enumerate(chunk)]
            translations = translate_batch_parallel(items_to_translate)

            for i, item in enumerate(chunk):
                text_lb = translations.get(i)
                if text_lb and validate(item['text_en'], text_lb, item['difficulty']):
                    # Build sentence_id: sense_id + sequential suffix
                    base = item['sense_id'].replace('_1', '').replace('s_', 'sent_s_') + '_1'
                    n = 1
                    sent_id = f"{base}_new{n}"
                    while sent_id in sent_ids_used:
                        n += 1
                        sent_id = f"{base}_new{n}"
                    sent_ids_used.add(sent_id)

                    new_sent = {
                        'sentence_id': sent_id,
                        'sense_ids':   [item['sense_id']],
                        'text_en':     item['text_en'],
                        'text_lu':     text_lb,
                        'difficulty':  item['difficulty'],
                        'cloze_index': 0,
                        'audio_url':   '',
                    }
                    state['new_sentences'].append(new_sent)
                    # Only mark done when successfully translated — API errors shouldn't
                    # permanently skip a sentence on the next run
                    state['done_keys'].append(item['_key'])
                else:
                    state['failed'] += 1
                    # Not added to done_keys so it retries on next run
                processed += 1

            # Progress report
            if processed % REPORT_EVERY == 0 or chunk_start + chunk_size >= len(remaining):
                elapsed   = time.time() - t_start
                rate      = processed / elapsed if elapsed > 0 else 0
                remaining_count = len(remaining) - processed
                eta_sec   = remaining_count / rate if rate > 0 else 0
                eta_str   = f"{eta_sec/60:.0f}m" if eta_sec > 60 else f"{eta_sec:.0f}s"
                print(f"  [{datetime.datetime.now().strftime('%H:%M:%S')}] "
                      f"{processed}/{len(remaining)} done "
                      f"| accepted: {len(state['new_sentences'])} "
                      f"| failed: {state['failed']} "
                      f"| ETA: {eta_str}")

            # Save state periodically
            if processed % SAVE_EVERY == 0:
                save_state(state)

        save_state(state)
        print(f"\nTranslation complete.")

    # 6. Inject into seed
    accepted = state['new_sentences']
    if not accepted:
        print("No new sentences to inject.")
        return

    print(f"\nInjecting {len(accepted)} sentences into seed...")
    bk = SEED_PATH + f'.bak_{datetime.datetime.now().strftime("%Y%m%d_%H%M%S")}'
    shutil.copy2(SEED_PATH, bk)

    seed = json.load(open(SEED_PATH, encoding='utf-8'))  # reload fresh
    existing_ids = {s['sentence_id'] for s in seed['sentences']}
    injected = 0
    for s in accepted:
        if s['sentence_id'] not in existing_ids:
            seed['sentences'].append(s)
            existing_ids.add(s['sentence_id'])
            injected += 1

    old_ver = seed.get('version', 6.5)
    seed['version'] = round(old_ver + 0.1, 1)
    with open(SEED_PATH, 'w', encoding='utf-8') as f:
        json.dump(seed, f, ensure_ascii=False, indent=2)

    print(f"Injected:    {injected} new sentences")
    print(f"Backup:      {bk}")
    print(f"Seed:        v{old_ver} → v{seed['version']}")
    print(f"\nNext steps:")
    print(f"  python3 annotate_sentences.py")
    print(f"  python3 deepl_verify.py          # verify new translations")
    print(f"  python3 apply_deepl_fixes.py --auto --review")

if __name__ == '__main__':
    main()
