# LuxLingo — English Sentence Generation Prompt

## Context

LuxLingo is a Luxembourgish language learning app (like Duolingo). We need high-quality English example sentences for each vocabulary word. These sentences are translated to Luxembourgish using the LuxMT API and used as exercise prompts throughout the app.

The sentences must be natural, A1-level English, and use a consistent cast of characters that recur across the whole course to create narrative continuity.

---

## Characters

Use these characters consistently. Try to maximize the recurrrence of the characters throughout the sentences. If it is too complex to force their usage in a sentence, you can omit them for that sentence, but try to use them as much as possible.

| Name | Role | Notes |
|---|---|---|
| **Marc** | Boy, ~10 years old | Anna's younger brother |
| **Anna** | Girl, ~12 years old | Marc's older sister |
| **Lena** | Their mother | Kind, cooks, works |
| **Paul** | Their father | Friendly, has a car |
| **Bello** | Their dog | Playful, brown |
| **Claire** | Their neighbour | Anna's friend, same age |
| **Mr. Weiss** | Their teacher | Calm, reads a lot |

Keep the world small and everyday: home, school, garden, kitchen, park. No exotic locations, no abstract situations.

---

## Difficulty Levels

Each word needs sentences at **3 difficulty levels**:

| Level | Description | Max words | Tense | Grammar |
|---|---|---|---|---|
| `simple` | The target word in its base/lemma form. Subject + verb + object only. | 7 | **Simple present only. Never use "will", "would", "could", "should", "has been" etc.** | No subordinate clauses |
| `intermediate` | One additional clause or modifier allowed. | 10 | Simple present or simple past | One conjunction (and/but/or/when) allowed |
| `advanced` | Richer context sentence. | 14 | Any natural tense | Subordinate clauses allowed |

**Critical rule for `simple` sentences**: The target word MUST appear in its exact dictionary form (lemma), not conjugated or modified. If the target word is "give", the sentence must contain the word "give" or "gives" — not "gave", "will give", "giving". This is essential for the app's cloze exercise engine.

---

## Sentence Rules (all levels)

1. The target word (or a direct form of it) **must appear** in the sentence.
2. Use only A1-level vocabulary: house, school, book, water, dog, cat, mother, father, garden, table, chair, door, bag, ball, milk, bread, apple, name, day, morning, evening.
3. Use the characters (Marc, Anna, Lena, Paul, Bello, Claire, Mr. Weiss) — not generic "he/she/they".
4. No contractions ("I'm", "don't"). Write "I am", "do not".
5. No idioms, no cultural references, no ambiguous pronouns.
6. Vary the sentence structure across the 3 levels — do not just add words to the simple version.

---

## Word List

For each entry below, generate exactly 10 sentences: 5 `simple`, 3 `intermediate`, 2 `advanced`.

The format is: `sense_id | word_lu | word_en | POS`

```
s_an_1 | an | and | CONJ
s_sinn_1 | sinn | be | VERB
s_hunn_1 | hunn | have | VERB
s_ech_1 | ech | I | PRON
s_fir_1 | fir | for | PREP
s_ginn_1 | ginn | give | VRB
s_op_1 | op | on | ADV
s_si_1 | si | she | PRON
s_mat_1 | mat | with | PREP
s_hien_1 | hien | he | PRON
s_vun_1 | vun | from | PREP
s_wéi_1 | wéi | how | PRON+INT
s_dat_1 | dat | that | PRON+DEM
s_en_1 | en | a | PRON+PERS
s_déi_1 | déi | they | PRON+DEM
s_mir_1 | mir | we | PRON+PERS
s_mä_1 | mä | but | CONJ
s_wat_1 | wat | what | PRON+INT
s_et_1 | et | it | PRON+PERS
s_dir_1 | dir | you | PRON+PERS
s_oder_1 | oder | or | CONJ
s_den_1 | den | the | ART+DEF
s_ze_1 | ze | too | ADV
s_kënnen_1 | kënnen | can | VRB+MOD
s_aner_1 | aner | other | PRON+INDEF
s_maachen_1 | maachen | make | VRB
s_hir_1 | hir | their | PRON+POSS
s_zäit_1 | Zäit | time | SUBST+F
s_wann_1 | wann | when | CONJ
s_wäert_1 | wäert | will | ADJ
s_soen_1 | soen | say | VRB
s_all_1 | all | every/all | PRON+INDEF
s_dëst_1 | dëst | this | PRON+DEM
s_waarm_1 | waarm | warm | ADJ
s_wuert_1 | Wuert | word | SUBST+N
s_puer_1 | puer | few | PRON+INDEF
s_eent_1 | eent | one | PRON+INDEF
s_säin_1 | säin | his | PRON+POSS
s_keen_1 | keen | none/no | PRON+INDEF
s_vill_1 | vill | much/many | ADV
s_goen_1 | goen | go | VRB
s_kommen_1 | kommen | come | VRB
s_elo_1 | elo | now | ADV
s_méi_1 | méi | more | ADV
s_och_1 | och | also | ADV
s_nees_1 | nees | again | ADV
s_ganz_1 | ganz | very | ADV
s_net_1 | net | not | PART
s_jo_1 | jo | yes | PART
s_mënsch_1 | Mënsch | person | SUBST+M
```

---

## Output Format

Output **only** a JSON array. No explanations, no headers, no markdown — just the raw JSON so it can be parsed directly by a script.

Each object has these exact keys:
- `sense_id` — from the word list above
- `difficulty` — `"simple"`, `"intermediate"`, or `"advanced"`
- `text_en` — the English sentence

Example of correct output format:
```json
[
  {"sense_id": "s_ginn_1", "difficulty": "simple", "text_en": "Marc gives Anna a book."},
  {"sense_id": "s_ginn_1", "difficulty": "intermediate", "text_en": "Marc gives Anna his old book from school."},
  {"sense_id": "s_ginn_1", "difficulty": "advanced", "text_en": "Every morning Marc gives Anna an apple from the kitchen before they go to school."},
  {"sense_id": "s_an_1", "difficulty": "simple", "text_en": "Marc and Anna are at home."},
  ...
]
```

Generate all 10 sentences for each of the 50 words in the word list. Total output: 500 sentence objects.
