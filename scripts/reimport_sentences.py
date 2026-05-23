#!/usr/bin/env python3
"""
reimport_sentences.py — Re-translate edited English sentences and update initial_seed.json.

Reads the CSV produced by export_sentences.py, finds rows where text_en has changed,
translates them via LuxMT, and patches the seed file.

Usage:
    python3 reimport_sentences.py LuxMT/sentences_edit.csv
    python3 reimport_sentences.py LuxMT/sentences_edit.csv --dry-run   # preview only
"""

import json, csv, sys, argparse, shutil, datetime, time, urllib.request

SEED_PATH = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
LUXMT_URL = 'https://luxasr.uni.lu/luxmt/translate'

def translate(text_en: str) -> str | None:
    payload = json.dumps({'text': text_en, 'source_lang': 'en', 'target_lang': 'lb'}).encode()
    req = urllib.request.Request(LUXMT_URL, data=payload,
                                 headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=12) as r:
            return json.loads(r.read()).get('translated_text')
    except Exception as e:
        print(f'    LuxMT error: {e}')
        return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('csv_file', help='Edited CSV file from export_sentences.py')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without saving')
    args = parser.parse_args()

    # Load seed
    seed = json.load(open(SEED_PATH, encoding='utf-8'))
    sent_index = {s['sentence_id']: i for i, s in enumerate(seed['sentences'])}

    # Load CSV
    with open(args.csv_file, newline='', encoding='utf-8') as f:
        rows = list(csv.DictReader(f))
    print(f"Loaded {len(rows)} rows from {args.csv_file}")

    # Find changed rows
    changed = []
    for row in rows:
        sid  = row['sentence_id']
        idx  = sent_index.get(sid)
        if idx is None:
            print(f"  WARN: {sid} not found in seed — skipping")
            continue
        current_en = seed['sentences'][idx]['text_en']
        new_en     = row['text_en'].strip()
        if new_en and new_en != current_en:
            changed.append((sid, idx, current_en, new_en))

    if not changed:
        print("No changes detected — nothing to do.")
        return

    print(f"\n{len(changed)} sentence(s) changed:")
    for sid, idx, old_en, new_en in changed:
        print(f"  {sid}")
        print(f"    OLD EN: {old_en}")
        print(f"    NEW EN: {new_en}")

    if args.dry_run:
        print("\n(dry-run — nothing saved)")
        return

    # Translate and apply
    applied = 0
    failed  = []
    for sid, idx, old_en, new_en in changed:
        print(f"\nTranslating: {new_en!r}")
        lb = translate(new_en)
        if lb:
            print(f"  LuxMT → {lb!r}")
            seed['sentences'][idx]['text_en'] = new_en
            seed['sentences'][idx]['text_lu'] = lb
            # Reset annotations so annotate_sentences.py re-processes
            seed['sentences'][idx].pop('cloze_confidence', None)
            seed['sentences'][idx].pop('n_rule_word_index', None)
            seed['sentences'][idx].pop('n_rule_form', None)
            seed['sentences'][idx].pop('exact_form', None)
            seed['sentences'][idx]['cloze_index'] = 0
            applied += 1
        else:
            print(f"  FAILED — keeping original")
            failed.append(sid)
        time.sleep(0.1)

    # Save
    if applied > 0:
        bk = SEED_PATH + f'.bak_{datetime.datetime.now().strftime("%Y%m%d_%H%M%S")}'
        shutil.copy2(SEED_PATH, bk)
        old_ver = seed.get('version', 6.0)
        seed['version'] = round(old_ver + 0.1, 1)
        with open(SEED_PATH, 'w', encoding='utf-8') as f:
            json.dump(seed, f, ensure_ascii=False, indent=2)
        print(f"\nSaved. Backup: {bk}")
        print(f"Seed version: {old_ver} → {seed['version']}")
        print(f"\nNext step: python3 annotate_sentences.py")

    print(f"\nApplied: {applied}  Failed: {len(failed)}")
    if failed:
        print("Failed IDs:", failed)

if __name__ == '__main__':
    main()
