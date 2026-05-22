#!/usr/bin/env python3
"""
fix_name_articles.py — Fix bare character names in LuxLingo initial_seed.json

Uses rule-based Luxembourgish grammar to apply definite articles (De/Den/D'/Der/Dem)
before character names, using the paired English sentence to determine grammatical case.

Characters:
  Feminine: Anna, Lena, Claire  →  nominative/accusative: D'/d'  |  dative: der
  Masculine: Marc, Paul, Bello  →  nominative: De/de  |  accusative: den  |  dative: dem

Usage:
    python3 fix_name_articles.py [--dry-run] [--show-changes]
"""

import json
import re
import sys
import shutil
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
SEED_PATH  = Path("/Users/nv/Projects/luxlingo/ios/LuxLingo/LuxLingo/Resources/initial_seed.json")
CACHE_PATH = Path("/Users/nv/Projects/luxlingo/LuxMT/deepl_cache.json")

# ── Character gender ───────────────────────────────────────────────────────────
FEMININE  = {"Anna", "Lena", "Claire"}
MASCULINE = {"Marc", "Paul", "Bello"}
CHARACTERS = FEMININE | MASCULINE

# ── Article forms ──────────────────────────────────────────────────────────────
# nom_cap  = capitalised nominative (start of sentence/clause)
# nom_low  = lowercase nominative (mid-sentence after conjunction)
# acc      = accusative (direct object)
# dat      = dative (after prepositions)
ARTICLES = {
    "feminine":  {"nom_cap": "D'",  "nom_low": "d'",  "acc": "d'",  "dat": "der"},
    "masculine": {"nom_cap": "De",  "nom_low": "de",  "acc": "den", "dat": "dem"},
}

def gender(name: str) -> str:
    return "feminine" if name in FEMININE else "masculine"

def article(name: str, form: str) -> str:
    return ARTICLES[gender(name)][form]


# ── English-based case detection ───────────────────────────────────────────────
# Prepositions that trigger dative
EN_DATIVE_PREPS = re.compile(
    r'\b(with|for|from|to|at|by|about|of|near|beside|next to|in front of|behind)\s+$',
    re.IGNORECASE
)

# Transitive verbs strongly suggesting accusative when followed by a name
EN_ACC_VERBS = re.compile(
    r'\b(see[s]?|saw|meet[s]?|met|visit[s]?|visited|help[s]?|helped|call[s]?|called|'
    r'love[s]?|loved|hug[s]?|hugged|kiss[es]?|kissed|invite[s]?|invited|ask[s]?|asked|'
    r'tell[s]?|told|teach[es]?|taught|show[s]?|showed|bring[s]?|brought|find[s]?|found|'
    r'hear[s]?|heard|know[s]?|knew|like[s]?|liked|miss[es]?|missed|need[s]?|needed|'
    r'send[s]?|sent|take[s]?|took|watch[es]?|watched|want[s]?|wanted|remind[s]?|reminded)\s+$',
    re.IGNORECASE
)

def detect_case_from_english(en_text: str, name: str) -> str:
    """
    Determine grammatical case for `name` based on the English sentence.
    Returns 'nom', 'acc', or 'dat'.
    """
    # Find position of name in English text
    m = re.search(r'\b' + re.escape(name) + r'\b', en_text, re.IGNORECASE)
    if not m:
        return 'nom'  # default

    before = en_text[:m.start()]

    # Dative: name follows a preposition
    if EN_DATIVE_PREPS.search(before):
        return 'dat'

    # Accusative: name follows a transitive verb
    if EN_ACC_VERBS.search(before):
        return 'acc'

    # Nominative: name is at/near the start of the sentence, or is the subject
    # Heuristic: if the name appears before the main verb in English, it's the subject
    # Simple check: is the name in the first ~40% of the sentence?
    if m.start() < len(en_text) * 0.5:
        return 'nom'

    # If after a coordinating conjunction ("and Marc"), check what precedes the conjunction
    conj_m = re.search(r'\b(and|but)\s+' + re.escape(name) + r'\b', en_text, re.IGNORECASE)
    if conj_m:
        # Name is in a conjunction — treat same case as the first name/subject in sentence
        return 'nom'  # conservative default

    return 'nom'


# ── Luxembourgish sentence fixer ───────────────────────────────────────────────

# Tokens that can legitimately precede a name (already-articled)
ALREADY_ARTICLED = re.compile(
    r"(?:^|(?<=\s))"
    r"(?:d'|de|den|dem|der|vum|vun|fir\s+d'|fir\s+de|fir\s+den|mat\s+der|mat\s+dem)"
    r"\s*$",
    re.IGNORECASE
)

LU_CONJ = re.compile(r'\b(an?)\s+$', re.IGNORECASE)  # "a" or "an" (Luxembourgish "and")

# Contracted preposition+article forms that already embed an article — do NOT add another
# mam = mat+dem, nom = no+dem, zum = zu+dem, vum = vun+dem, am = an+dem
LU_CONTRACTED = {"mam", "nom", "zum", "zur", "vum", "am", "vum"}

# Prepositions that govern dative case for personal names in Luxembourgish
# NOTE: "fir" governs ACCUSATIVE, not dative — excluded intentionally
# NOTE: "während" is a temporal conjunction, not a dative preposition — excluded
LU_DATIVE_PREPS = re.compile(
    r'\b(mat|vun|bei|wéinst|duerch|ouni|géint|'
    r'zënter|bis|trotz|laanscht|virun|hannert|'
    r'nieft|iwwer|ënner|tëschent)\s+$',
    re.IGNORECASE
)

# Prepositions that govern accusative case
LU_ACC_PREPS = re.compile(
    r'\b(fir|duerch|ouni|géint|entlang)\s+$',
    re.IGNORECASE
)

def fix_lu_sentence(text_lu: str, text_en: str) -> str:
    """
    Return a corrected Luxembourgish sentence with proper articles before character names.
    Returns the original string if no change was needed.
    """
    NAME_PAT = re.compile(r'\b(' + '|'.join(re.escape(n) for n in CHARACTERS) + r')\b')

    result = []
    prev_end = 0

    for m in NAME_PAT.finditer(text_lu):
        name = m.group()
        start = m.start()
        segment_before = text_lu[prev_end:start]

        # Text immediately before this match (within the current segment)
        before_this = text_lu[:start]

        # Check if already has an article
        before_stripped = before_this.rstrip()
        if before_stripped.endswith("'"):
            # e.g. "d'Anna" — already has article
            result.append(segment_before)
            result.append(name)
            prev_end = m.end()
            continue

        words_before = before_stripped.split()
        last_word = words_before[-1].lower() if words_before else ""

        # Already articled? (explicit article word or contracted form that embeds one)
        already_ok = (
            last_word in {"d'", "de", "den", "dem", "der", "vum", "vun"}
            or last_word in LU_CONTRACTED
        )
        if already_ok:
            result.append(segment_before)
            result.append(name)
            prev_end = m.end()
            continue

        # ── Determine form ──────────────────────────────────────────────────
        # Is this name at the very start of the sentence (or after sentence-start)?
        at_start = not before_stripped or before_stripped.endswith((".", "!", "?", ":"))

        # After a Luxembourgish conjunction ("a Marc", "an Anna")?
        after_conj = bool(LU_CONJ.search(before_this))

        # Determine case based on surrounding prepositions
        if LU_DATIVE_PREPS.search(before_this) or last_word in {"mat", "vun", "bei"}:
            case = 'dat'
        elif LU_ACC_PREPS.search(before_this) or last_word in {"fir"}:
            case = 'acc'
        else:
            case = detect_case_from_english(text_en, name)

        # Determine capitalisation
        if at_start:
            form = "nom_cap"
        elif after_conj:
            form = "nom_low"
        else:
            form = {"nom": "nom_low", "acc": "acc", "dat": "dat"}[case]

        art = article(name, form)

        # Feminine: article ends with apostrophe — attach directly (no space)
        if art.endswith("'"):
            art_with_sep = art  # "d'Anna" not "d' Anna"
        else:
            art_with_sep = art + " "

        result.append(segment_before)
        result.append(art_with_sep)
        result.append(name)
        prev_end = m.end()

    result.append(text_lu[prev_end:])
    corrected = "".join(result)

    # Normalise spacing: "d' Anna" → "d'Anna" (safety pass)
    corrected = re.sub(r"d'\s+", "d'", corrected)

    return corrected


# ── Bare-name detection ────────────────────────────────────────────────────────

NAME_PAT_GLOBAL = re.compile(r'\b(' + '|'.join(re.escape(n) for n in CHARACTERS) + r')\b')

def has_bare_name(text_lu: str) -> bool:
    for m in NAME_PAT_GLOBAL.finditer(text_lu):
        start = m.start()
        before = text_lu[:start].rstrip()
        if not before:
            return True
        last_char = before[-1]
        if last_char == "'":
            continue  # "d'Anna" style
        last_word = before.split()[-1].lower()
        if last_word not in {"de", "den", "dem", "der", "d'", "vum", "vun"}:
            return True
    return False


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    dry_run      = "--dry-run"      in sys.argv
    show_changes = "--show-changes" in sys.argv or dry_run

    print(f"Loading {SEED_PATH} …")
    with open(SEED_PATH, encoding="utf-8") as f:
        seed = json.load(f)

    sentences = seed["sentences"]
    print(f"  {len(sentences):,} sentences total")

    to_fix = [s for s in sentences if has_bare_name(s.get("text_lu", ""))]
    print(f"  {len(to_fix):,} sentences with bare character names")

    if not to_fix:
        print("Nothing to fix — exiting.")
        return

    if not dry_run:
        bak = SEED_PATH.with_suffix(".json.bak")
        shutil.copy2(SEED_PATH, bak)
        print(f"  Backed up to {bak.name}")

    # ── Apply corrections ──────────────────────────────────────────────────────
    corrections: dict[str, str] = {}
    for s in to_fix:
        old = s["text_lu"]
        new = fix_lu_sentence(old, s.get("text_en", ""))
        if new != old:
            corrections[s["sentence_id"]] = new

    print(f"  {len(corrections):,} sentences corrected\n")

    changed = 0
    for s in sentences:
        sid = s["sentence_id"]
        if sid in corrections:
            old_lu = s["text_lu"]
            new_lu = corrections[sid]
            if show_changes:
                changed += 1
                if changed <= 20 or changed % 200 == 0:
                    print(f"  [{changed}] {old_lu}")
                    print(f"       → {new_lu}")
            if not dry_run:
                s["text_lu"] = new_lu

    # ── Save ───────────────────────────────────────────────────────────────────
    if not dry_run:
        with open(SEED_PATH, "w", encoding="utf-8") as f:
            json.dump(seed, f, ensure_ascii=False, indent=2)
        print(f"\n✅ Saved {SEED_PATH.name} — {len(corrections):,} sentences corrected.")

        # Update deepl_cache too (where EN key matches)
        if CACHE_PATH.exists():
            with open(CACHE_PATH, encoding="utf-8") as f:
                cache = json.load(f)

            # Build a lookup: sentence_id → text_en (for sentences we corrected)
            id_to_en = {s["sentence_id"]: s["text_en"] for s in to_fix}
            id_to_old_lu: dict[str, str] = {}
            for s in to_fix:
                id_to_old_lu[s["sentence_id"]] = s.get("_old_lu", "")

            # Re-read originals before we saved
            cache_updated = 0
            for s in to_fix:
                sid = s["sentence_id"]
                if sid not in corrections:
                    continue
                en = s.get("text_en", "")
                if en in cache:
                    cache[en] = corrections[sid]
                    cache_updated += 1

            if cache_updated:
                bak2 = CACHE_PATH.with_suffix(".json.bak")
                shutil.copy2(CACHE_PATH, bak2)
                with open(CACHE_PATH, "w", encoding="utf-8") as f:
                    json.dump(cache, f, ensure_ascii=False, indent=2)
                print(f"  Updated {cache_updated:,} entries in {CACHE_PATH.name}")
    else:
        print(f"\n[DRY RUN] {len(corrections):,} sentences would be corrected.")
        print("Run without --dry-run to apply.")


if __name__ == "__main__":
    main()
