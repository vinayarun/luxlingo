"""
Export LuxLingo sentences to a single Excel sheet for native-speaker review.

Usage:
    python3 tools/export_sentences.py

Output:
    luxlingo_review.xlsx  (same directory as this script)
"""

import json
import sys
from pathlib import Path

try:
    import xlsxwriter
except ImportError:
    sys.exit("xlsxwriter not found. Run: pip3 install xlsxwriter")

SEED_PATH = Path(__file__).parent.parent / "ios/LuxLingo/LuxLingo/Resources/initial_seed.json"
OUT_PATH  = Path(__file__).parent.parent / "luxlingo_review.xlsx"

# ── Load data ──────────────────────────────────────────────────────────────────

with open(SEED_PATH, encoding="utf-8") as f:
    data = json.load(f)

sentences      = data["sentences"]
senses_raw     = data["senses"]
vocabulary_raw = data["vocabulary"]
curriculum     = data["curriculum"]
article_exs    = data["article_exercises"]

# ── Build lookup maps ──────────────────────────────────────────────────────────

# sense_id → primary_en, surface_id
sense_map = {s["sense_id"]: s for s in senses_raw}

# surface_id → word_lu
vocab_map = {v["surface_id"]: v["word_lu"] for v in vocabulary_raw}

# sense_id → lesson number (may appear in multiple lessons; take the first/lowest)
sense_to_lessons: dict[str, list[int]] = {}
for lesson in curriculum:
    num = int(lesson["lesson_id"].replace("lesson_", ""))
    for sid in lesson["core_senses"] + lesson.get("secondary_senses", []):
        sense_to_lessons.setdefault(sid, []).append(num)

def lesson_label(sense_ids: list[str]) -> str:
    nums = set()
    for sid in sense_ids:
        nums.update(sense_to_lessons.get(sid, []))
    if not nums:
        return ""
    mn, mx = min(nums), max(nums)
    return str(mn) if mn == mx else f"{mn}–{mx}"

def target_word(sense_ids: list[str]) -> str:
    words = []
    for sid in sense_ids:
        s = sense_map.get(sid, {})
        surf = s.get("surface_id", "")
        w = vocab_map.get(surf, "")
        if w and w not in words:
            words.append(w)
    return ", ".join(words)

def target_meaning(sense_ids: list[str]) -> str:
    meanings = []
    for sid in sense_ids:
        m = sense_map.get(sid, {}).get("primary_en", "")
        if m and m not in meanings:
            meanings.append(m)
    return ", ".join(meanings)

# ── Build rows ─────────────────────────────────────────────────────────────────

rows = []
for sent in sentences:
    rows.append({
        "lesson":      lesson_label(sent["sense_ids"]),
        "sentence_lu": sent["text_lu"],
        "sentence_en": sent["text_en"],
        "word_lu":     target_word(sent["sense_ids"]),
        "meaning_en":  target_meaning(sent["sense_ids"]),
        "difficulty":  sent.get("difficulty", ""),
        "sentence_id": sent["sentence_id"],
    })

# Sort by lesson number (numeric), then difficulty order, then LU text
DIFF_ORDER = {"simple": 0, "intermediate": 1, "advanced": 2}
def sort_key(r):
    parts = r["lesson"].split("–")
    try:
        n = int(parts[0]) if parts[0] else 999
    except ValueError:
        n = 999
    return (n, DIFF_ORDER.get(r["difficulty"], 9), r["sentence_lu"])

rows.sort(key=sort_key)

# Add article exercises as extra rows at the bottom
for ex in article_exs:
    s = sense_map.get(ex["sense_id"], {})
    surf = s.get("surface_id", "")
    w = vocab_map.get(surf, s.get("primary_en", ""))
    rows.append({
        "lesson":      "Article",
        "sentence_lu": ex["text_lu"].replace("___", ex["correct"]),
        "sentence_en": ex["text_en"],
        "word_lu":     w,
        "meaning_en":  s.get("primary_en", ""),
        "difficulty":  ex.get("difficulty", ""),
        "sentence_id": ex["id"],
    })

# ── Write Excel ────────────────────────────────────────────────────────────────

wb = xlsxwriter.Workbook(str(OUT_PATH))
ws = wb.add_worksheet("Sentences")

# Formats
hdr_fmt = wb.add_format({
    "bold": True, "bg_color": "#1A1A2E", "font_color": "#FFFFFF",
    "border": 1, "text_wrap": True, "valign": "vcenter", "align": "center",
})
lu_fmt = wb.add_format({
    "text_wrap": True, "valign": "top", "font_size": 11,
})
en_fmt = wb.add_format({
    "text_wrap": True, "valign": "top", "font_color": "#555555",
})
meta_fmt = wb.add_format({
    "valign": "top", "align": "center", "font_color": "#888888", "font_size": 9,
})
note_fmt = wb.add_format({
    "valign": "top", "bg_color": "#FFFFF0", "border": 1, "border_color": "#DDDDAA",
})
alt_lu_fmt = wb.add_format({
    "text_wrap": True, "valign": "top", "font_size": 11, "bg_color": "#F8F8FC",
})
alt_en_fmt = wb.add_format({
    "text_wrap": True, "valign": "top", "font_color": "#555555", "bg_color": "#F8F8FC",
})
alt_meta_fmt = wb.add_format({
    "valign": "top", "align": "center", "font_color": "#888888",
    "font_size": 9, "bg_color": "#F8F8FC",
})
alt_note_fmt = wb.add_format({
    "valign": "top", "bg_color": "#FFFFF8", "border": 1, "border_color": "#DDDDAA",
})

# Column widths
COLS = [
    ("Lesson",            6),
    ("Luxembourgish",    48),
    ("English",          38),
    ("Word (LU)",        14),
    ("Meaning (EN)",     16),
    ("Difficulty",       10),
    ("Reviewer Notes",   30),
    ("Sentence ID",      24),
]
for col_i, (title, width) in enumerate(COLS):
    ws.set_column(col_i, col_i, width)
    ws.write(0, col_i, title, hdr_fmt)

ws.set_row(0, 22)
ws.freeze_panes(1, 0)

# Data rows
for row_i, r in enumerate(rows, start=1):
    alt = row_i % 2 == 0
    lf  = alt_lu_fmt   if alt else lu_fmt
    ef  = alt_en_fmt   if alt else en_fmt
    mf  = alt_meta_fmt if alt else meta_fmt
    nf  = alt_note_fmt if alt else note_fmt

    ws.write(row_i, 0, r["lesson"],      mf)
    ws.write(row_i, 1, r["sentence_lu"], lf)
    ws.write(row_i, 2, r["sentence_en"], ef)
    ws.write(row_i, 3, r["word_lu"],     mf)
    ws.write(row_i, 4, r["meaning_en"],  mf)
    ws.write(row_i, 5, r["difficulty"],  mf)
    ws.write(row_i, 6, "",               nf)   # Reviewer Notes (blank)
    ws.write(row_i, 7, r["sentence_id"], mf)

ws.autofilter(0, 0, len(rows), len(COLS) - 1)

# ── Sheet 2: Thematic lessons ──────────────────────────────────────────────────

THEMATIC_PATH = Path(__file__).parent.parent / "content/thematic_lessons.json"
with open(THEMATIC_PATH, encoding="utf-8") as f:
    thematic = json.load(f)

ws2 = wb.add_worksheet("Thematic Lessons")

TCOLS = [
    ("Topic",            18),
    ("Type",              9),
    ("Luxembourgish",    44),
    ("English",          36),
    ("Notes / Context",  22),
    ("Difficulty",       10),
    ("Reviewer Notes",   30),
]
for col_i, (title, width) in enumerate(TCOLS):
    ws2.set_column(col_i, col_i, width)
    ws2.write(0, col_i, title, hdr_fmt)

ws2.set_row(0, 22)
ws2.freeze_panes(1, 0)

# Section header format
sec_fmt = wb.add_format({
    "bold": True, "bg_color": "#2E4057", "font_color": "#FFFFFF",
    "font_size": 10, "valign": "vcenter",
})

t_row = 1
t_row_count = 0

for lesson in thematic["thematic_lessons"]:
    topic = lesson["title_en"]

    # Section header row spanning all columns
    ws2.merge_range(t_row, 0, t_row, len(TCOLS) - 1,
                    f"{topic}  —  {lesson['title_lu']}  ({lesson['situation']})", sec_fmt)
    ws2.set_row(t_row, 18)
    t_row += 1

    # Vocabulary rows
    for item in lesson.get("vocabulary", []):
        alt = t_row % 2 == 0
        lf = alt_lu_fmt if alt else lu_fmt
        ef = alt_en_fmt if alt else en_fmt
        mf = alt_meta_fmt if alt else meta_fmt
        nf = alt_note_fmt if alt else note_fmt
        ws2.write(t_row, 0, topic,              mf)
        ws2.write(t_row, 1, "vocab",            mf)
        ws2.write(t_row, 2, item["word_lu"],    lf)
        ws2.write(t_row, 3, item.get("meaning_en", item.get("text_en", "")), ef)
        ws2.write(t_row, 4, item.get("notes", ""), mf)
        ws2.write(t_row, 5, item.get("pos", ""),   mf)
        ws2.write(t_row, 6, "",                 nf)
        t_row += 1
        t_row_count += 1

    # Sentence rows
    for sent in lesson.get("sentences", []):
        alt = t_row % 2 == 0
        lf = alt_lu_fmt if alt else lu_fmt
        ef = alt_en_fmt if alt else en_fmt
        mf = alt_meta_fmt if alt else meta_fmt
        nf = alt_note_fmt if alt else note_fmt
        ws2.write(t_row, 0, topic,                           mf)
        ws2.write(t_row, 1, "sentence",                      mf)
        ws2.write(t_row, 2, sent["text_lu"],                 lf)
        ws2.write(t_row, 3, sent["text_en"],                 ef)
        ws2.write(t_row, 4, ", ".join(sent.get("topic_tags", [])), mf)
        ws2.write(t_row, 5, sent.get("difficulty", ""),      mf)
        ws2.write(t_row, 6, "",                              nf)
        t_row += 1
        t_row_count += 1

    # Dialogue rows
    for dialogue in lesson.get("dialogues", []):
        for line in dialogue.get("lines", []):
            alt = t_row % 2 == 0
            lf = alt_lu_fmt if alt else lu_fmt
            ef = alt_en_fmt if alt else en_fmt
            mf = alt_meta_fmt if alt else meta_fmt
            nf = alt_note_fmt if alt else note_fmt
            ws2.write(t_row, 0, topic,                                    mf)
            ws2.write(t_row, 1, f"dialogue",                              mf)
            ws2.write(t_row, 2, f"{line['speaker']}: {line['lu']}",       lf)
            ws2.write(t_row, 3, f"{line['speaker']}: {line['en']}",       ef)
            ws2.write(t_row, 4, dialogue["title"],                        mf)
            ws2.write(t_row, 5, "",                                       mf)
            ws2.write(t_row, 6, "",                                       nf)
            t_row += 1
            t_row_count += 1

ws2.autofilter(0, 0, t_row - 1, len(TCOLS) - 1)

wb.close()
print(f"Sheet 1: {len(rows)} lesson sentences → {OUT_PATH}")
print(f"Sheet 2: {t_row_count} thematic rows across {len(thematic['thematic_lessons'])} topics")
