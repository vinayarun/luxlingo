#!/usr/bin/env python3
"""
apply_deepl_fixes.py — Apply DeepL corrections to initial_seed.json.

Reads deepl_report.json and processes flagged sentences in three tiers:

  TIER 1  char_sim < 0.40 AND word_jaccard == 0.0
          → Completely different language (French/German fallback).
            Auto-applied with --auto, shown in --dry-run.

  TIER 2  char_sim 0.40–0.60
          → Both are Luxembourgish but structurally different.
            Presented for interactive review with --review.

  TIER 3  char_sim > 0.60
          → Synonym / word-order variation. Likely both valid.
            Ignored (not touched).

Usage:
    python3 apply_deepl_fixes.py --dry-run          # preview Tier 1 changes
    python3 apply_deepl_fixes.py --auto             # apply Tier 1 silently
    python3 apply_deepl_fixes.py --review           # interactive Tier 2 review
    python3 apply_deepl_fixes.py --auto --review    # both together
    python3 apply_deepl_fixes.py --reset            # clear saved progress

After applying, run:
    python3 annotate_sentences.py
to re-fix cloze indices for updated sentences.
"""

import json, os, sys, shutil, datetime, argparse

SEED_PATH   = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
REPORT_PATH = 'LuxMT/deepl_report.json'
STATE_PATH  = 'LuxMT/apply_state.json'

TIER1_MAX_CHAR = 0.40   # auto-apply below this if word_jaccard == 0.0
TIER2_MAX_CHAR = 0.60   # review up to this; skip everything above

# Sentences excluded from Tier 1 auto-apply after manual review:
# - LuxMT was correct, or neither translation is right
TIER1_EXCLUDE = {
    'sent_s_stëft_1_simple',           # Blue pen: LuxMT "Blo Stëft" correct, DeepL returned German
    'sent_s_an der tëschenzäit_1_simple',  # In meantime: LuxMT "An der Tëschenzäit" is valid LB
    'sent_s_ewech_1_simple',           # Gone away: LuxMT "Ewech" is valid LB
    'sent_s_iergendwou_1_simple',      # Somewhere: neither translation is accurate
    'sent_s_soen_1_simple',            # I say hello: LuxMT "Moien" is more natural
}

# ── helpers ──────────────────────────────────────────────────────────────────

def load_state():
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH, encoding='utf-8') as f:
            return json.load(f)
    return {'applied': [], 'kept': [], 'skipped': [], 'processed': []}

def save_state(state):
    with open(STATE_PATH, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2)

def backup_seed():
    ts = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    bk = SEED_PATH + f'.bak_{ts}'
    shutil.copy2(SEED_PATH, bk)
    return bk

def tier(char_sim, word_jac):
    if char_sim < TIER1_MAX_CHAR and word_jac == 0.0:
        return 1
    if char_sim < TIER2_MAX_CHAR:
        return 2
    return 3

def reset_annotations(sentence):
    """Zero out annotation fields so annotate_sentences.py re-processes this sentence."""
    sentence.pop('cloze_confidence', None)
    sentence.pop('n_rule_word_index', None)
    sentence.pop('n_rule_form', None)
    sentence.pop('exact_form', None)
    sentence['cloze_index'] = 0

# ── main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter,
                                     epilog=__doc__)
    parser.add_argument('--auto',    action='store_true', help='Auto-apply Tier 1 fixes')
    parser.add_argument('--review',  action='store_true', help='Interactively review Tier 2')
    parser.add_argument('--dry-run', dest='dry_run', action='store_true',
                        help='Show what would change (no writes)')
    parser.add_argument('--reset',   action='store_true', help='Clear saved progress')
    args = parser.parse_args()

    if not (args.auto or args.review or args.dry_run):
        parser.print_help()
        sys.exit(0)

    if args.reset and os.path.exists(STATE_PATH):
        os.remove(STATE_PATH)
        print("Progress state cleared.\n")

    report  = json.load(open(REPORT_PATH, encoding='utf-8'))
    flagged = report['results']

    state   = load_state()
    done    = set(state['processed'])

    # Tier breakdown summary
    t1 = [x for x in flagged if tier(x['char_similarity'], x['word_jaccard']) == 1]
    t2 = [x for x in flagged if tier(x['char_similarity'], x['word_jaccard']) == 2]
    t3 = [x for x in flagged if tier(x['char_similarity'], x['word_jaccard']) == 3]
    print(f"Report: {len(flagged)} flagged entries")
    print(f"  Tier 1 (auto-apply, wrong language) : {len(t1)}")
    print(f"  Tier 2 (review, different phrasing) : {len(t2)}")
    print(f"  Tier 3 (skipped, minor variation)   : {len(t3)}")
    print(f"  Already processed                   : {len(done)}")
    print()

    # Load seed and build index
    with open(SEED_PATH, encoding='utf-8') as f:
        seed = json.load(f)
    sent_idx = {s['sentence_id']: i for i, s in enumerate(seed['sentences'])}

    applied = 0
    kept    = 0
    skipped = 0

    # ── TIER 1: auto-apply ──────────────────────────────────────────────────
    if args.auto or args.dry_run:
        print(f"{'─'*60}")
        print(f"TIER 1 — {'DRY RUN' if args.dry_run else 'Auto-applying'} {len(t1)} wrong-language sentences")
        print(f"{'─'*60}")
        for item in t1:
            sid = item['sentence_id']
            if sid in done or sid in TIER1_EXCLUDE:
                continue
            print(f"\n  [{item['char_similarity']}/{item['word_jaccard']}] {item['text_en']}")
            print(f"    LuxMT : {item['luxmt_lb']}")
            print(f"    DeepL : {item['deepl_lb']}")
            if not args.dry_run:
                idx = sent_idx.get(sid)
                if idx is not None:
                    seed['sentences'][idx]['text_lu'] = item['deepl_lb']
                    reset_annotations(seed['sentences'][idx])
                applied += 1
                state['applied'].append(sid)
                state['processed'].append(sid)
        if not args.dry_run:
            print(f"\n  ✓ Applied {applied} Tier 1 fixes")

    # ── TIER 2: interactive review ──────────────────────────────────────────
    if args.review:
        todo = [x for x in t2 if x['sentence_id'] not in done]
        if not todo:
            print("\nTier 2: nothing left to review.")
        else:
            print(f"\n{'─'*60}")
            print(f"TIER 2 — Interactive review ({len(todo)} remaining)")
            print(f"  [a] accept DeepL  [k] keep LuxMT  [s] skip  [q] quit")
            print(f"{'─'*60}")
            t2_applied = t2_kept = t2_skipped = 0
            for i, item in enumerate(todo, 1):
                sid = item['sentence_id']
                print(f"\n[{i}/{len(todo)}] char={item['char_similarity']}  word={item['word_jaccard']}")
                print(f"  EN:    {item['text_en']}")
                print(f"  LuxMT: {item['luxmt_lb']}")
                print(f"  DeepL: {item['deepl_lb']}")
                if item['only_in_luxmt']:
                    print(f"  LuxMT only: {item['only_in_luxmt']}")
                if item['only_in_deepl']:
                    print(f"  DeepL only: {item['only_in_deepl']}")

                while True:
                    choice = input("  > ").strip().lower()
                    if choice in ('a', 'k', 's', 'q'):
                        break
                    print("  Enter a / k / s / q")

                if choice == 'q':
                    save_state(state)
                    print(f"\nStopped. Applied={t2_applied} Kept={t2_kept} Skipped={t2_skipped}")
                    break

                state['processed'].append(sid)
                if choice == 'a':
                    idx = sent_idx.get(sid)
                    if idx is not None:
                        seed['sentences'][idx]['text_lu'] = item['deepl_lb']
                        reset_annotations(seed['sentences'][idx])
                    t2_applied += 1
                    applied += 1
                    state['applied'].append(sid)
                elif choice == 'k':
                    t2_kept += 1
                    kept += 1
                    state['kept'].append(sid)
                else:
                    t2_skipped += 1
                    skipped += 1
                    state['skipped'].append(sid)

                if len(state['processed']) % 20 == 0:
                    save_state(state)
            else:
                print(f"\n  Tier 2 complete. Applied={t2_applied} Kept={t2_kept} Skipped={t2_skipped}")

    # ── Write seed ──────────────────────────────────────────────────────────
    save_state(state)

    total_applied = len(state['applied'])
    print(f"\n{'='*60}")
    print(f"Session : applied={applied}  kept={kept}  skipped={skipped}")
    print(f"Lifetime: applied={total_applied}  kept={len(state['kept'])}  skipped={len(state['skipped'])}")

    if applied > 0 and not args.dry_run:
        bk = backup_seed()
        print(f"\nBackup  : {bk}")
        old_ver = seed.get('version', 5.0)
        seed['version'] = round(old_ver + 0.1, 1)
        with open(SEED_PATH, 'w', encoding='utf-8') as f:
            json.dump(seed, f, ensure_ascii=False, indent=2)
        print(f"Seed    : updated to v{seed['version']} ({applied} sentences replaced)")
        print(f"\nNext step: python3 annotate_sentences.py")
        print(f"           (re-fixes cloze indices for updated sentences)")
    elif args.dry_run:
        print("\n(dry-run — nothing written)")

if __name__ == '__main__':
    main()
