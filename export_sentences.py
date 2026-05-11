#!/usr/bin/env python3
"""
export_sentences.py — Export all lesson sentences to a CSV for manual review/editing.

Each row = one sentence.
Columns:
  sentence_id   — unique ID (don't change this)
  sense_id      — which word this sentence belongs to
  word_lb       — the Luxembourgish word being taught
  meaning_en    — its English meaning
  difficulty    — simple / intermediate / advanced
  text_en       — English sentence  ← EDIT THIS COLUMN
  text_lu       — current Luxembourgish translation (for reference, do not edit)

After editing, run:
    python3 reimport_sentences.py LuxMT/sentences_edit.csv

Usage:
    python3 export_sentences.py                          # exports all sentences
    python3 export_sentences.py --sense s_mä_1 s_an_1   # only these senses
    python3 export_sentences.py --lesson lesson_1        # only lesson 1 words
"""

import json, csv, argparse, sys

SEED_PATH = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
OUT_PATH  = 'LuxMT/sentences_edit.csv'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sense',  nargs='*', help='Filter to these sense IDs')
    parser.add_argument('--lesson', nargs='*', help='Filter to senses in these lesson IDs')
    parser.add_argument('--out',    default=OUT_PATH, help='Output CSV path')
    args = parser.parse_args()

    seed = json.load(open(SEED_PATH, encoding='utf-8'))

    # Build lookup maps
    senses  = {s['sense_id']: s for s in seed['senses']}
    vocab   = {v['surface_id']: v for v in seed['vocabulary']}

    # Build sense → lesson number map (first lesson the sense appears in)
    sense_lesson: dict[str, int] = {}
    for unit in seed.get('curriculum', []):
        lesson_num = int(unit['lesson_id'].replace('lesson_', '')) if unit['lesson_id'].replace('lesson_', '').isdigit() else 9999
        for sid in unit.get('core_senses', []):
            if sid not in sense_lesson:
                sense_lesson[sid] = lesson_num

    # Determine which sense_ids to include
    target_senses = None
    if args.sense:
        target_senses = set(args.sense)
    elif args.lesson:
        target_senses = set()
        for unit in seed.get('curriculum', []):
            if unit['lesson_id'] in args.lesson:
                target_senses.update(unit.get('core_senses', []))

    rows = []
    for sent in seed['sentences']:
        sid = sent.get('sense_ids', [sent.get('sense_id', '')])
        if isinstance(sid, str): sid = [sid]
        primary_sense = sid[0] if sid else ''

        if target_senses and primary_sense not in target_senses:
            continue

        sense_obj = senses.get(primary_sense, {})
        surf_id   = sense_obj.get('surface_id', '')
        word_lb   = vocab.get(surf_id, {}).get('word_lb', surf_id)

        rows.append({
            'sentence_id': sent['sentence_id'],
            'sense_id':    primary_sense,
            'lesson':      sense_lesson.get(primary_sense, 9999),
            'word_lb':     word_lb,
            'meaning_en':  sense_obj.get('translations', sense_obj.get('primary_en', '')),
            'difficulty':  sent.get('difficulty', ''),
            'text_en':     sent.get('text_en', ''),
            'text_lu':     sent.get('text_lu', ''),
        })

    # Sort by lesson number → sense within lesson → difficulty → sentence
    diff_order = {'simple': 0, 'intermediate': 1, 'advanced': 2}
    rows.sort(key=lambda r: (r['lesson'], r['sense_id'], diff_order.get(r['difficulty'], 9), r['sentence_id']))

    with open(args.out, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=[
            'lesson', 'sentence_id', 'sense_id', 'word_lb', 'meaning_en',
            'difficulty', 'text_en', 'text_lu'
        ])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Exported {len(rows)} sentences → {args.out}")
    print(f"Open in Numbers or Excel, edit the 'text_en' column, save as CSV.")
    print(f"Then run:  python3 reimport_sentences.py {args.out}")

if __name__ == '__main__':
    main()
