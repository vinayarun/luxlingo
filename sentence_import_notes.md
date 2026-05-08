# Sentence Import — Batch 1 (May 2026)

## What we did
Generated 500 English sentences (50 words × 10 sentences: 5 simple, 3 intermediate, 2 advanced)
using the prompt at `sentence_generation_prompt.md`, fed to an external LLM (Claude).
Characters used: Marc, Anna, Lena, Paul, Bello, Claire, Mr. Weiss.

Imported via `import_sentences.py` → `annotate_sentences.py`. Three passes required.

## Pipeline
1. LLM writes JSON to `LuxMT/sentences_en_batch.json`
2. `python3 import_sentences.py LuxMT/sentences_en_batch.json` — translates via LuxMT, applies A/B/C filters, validates LB word presence
3. `python3 annotate_sentences.py` — fixes cloze indices, annotates n-rule and exact_form

## Results
| Pass | Injected | Notes |
|------|---------|-------|
| 1st  | 336 | Baseline run |
| 2nd  | 86  | Fixed: paradigm extraction bug (reflexive pronoun), declined forms map, Filter C exemption for wäert |
| 3rd  | 35  | Extended declined forms map, apostrophe tokenisation fix |
| **Total** | **457** | Out of 500 (91.4% pass rate) |

Seed version: 4.7 → 5.3

## Fixes applied to import_sentences.py

### Bug: paradigm_forms extracted reflexive pronoun instead of verb
Rows like `"ech maachen (mech)"` had `parts[-1]` = `"(mech)"`. Fixed by stripping
parenthesised tokens before taking the last word.

### Bug: apostrophe-elided words not tokenised
`"d'anner"` was cleaned to `"danner"` (one token), so `"anner"` was never found.
Fixed by splitting on `[\s'']` before tokenising in `word_present`.

### Feature: LB_DECLINED_FORMS map
Added explicit map of lemma → accepted inflected/variant/synonym forms:

| Lemma | Accepted forms added |
|-------|---------------------|
| aner  | aneren, anere, anert, anner, anneren, annert |
| eent  | een, eng, e, engem, enger |
| en    | eng, engem, enger |
| hir   | hire, hiren, hiert, hirem, hirer |
| dëst  | dësen, dës, dësem, dëser, dëse |
| dat   | dee, deen, dës, dëser, dësem, dass |
| déi   | si, se (LuxMT uses si/se for "they") |
| si    | se (clitic form in subordinate clauses) |
| hien  | him, en (dative and clitic) |
| säin  | säi, seng, sengen, sengem, senger |
| keen  | keng, kengem, kenger, keenge |
| waarm | waarmen, waarmer, waarmt, waarme |
| mä    | awer, mee (LuxMT synonyms for "but") |
| wäert | wäerten, wäerts |
| wann  | wenn (German-influenced spelling) |
| nees  | erëm (LuxMT prefers this synonym) |
| mënsch| persoun, persoune (LuxMT prefers Persoun) |
| wuert | wort, wuerts (LuxMT uses German spelling) |

### Feature: Filter C exemption for s_wäert_1
`is_complex_lb` no longer rejects "wäert" for the `s_wäert_1` sense —
"wäert" IS the word being taught.

## Irreducible failures (~43 sentences)
These cannot be fixed by map entries and are expected losses:

| Sense | Reason |
|-------|--------|
| s_fir_1 | "wait for"→"waarden op", "look for"→"sichen" — different prepositions |
| s_op_1 | "on the floor"→"um Buedem" — prepositional contraction |
| s_dir_1 | "dir" only appears as dative indirect object; subject/object "you"→"du"/"dech" |
| s_den_1 | Gender-dependent: feminine/neuter nouns use d'/déi/dat, not "den" |
| s_ze_1 | "too much"→"zu vill" (spaced) — LuxMT uses "zu" not "ze" in this idiom |
| s_maachen_1 | LuxMT uses fabrizéieren/bauen/bereet for specific "make" contexts |
| s_mä_1 | Conjunction dropped entirely (just comma) in ~3 sentences |
| s_net_1 | "does not have"→"huet kee/keng" — negation with determiner |
| s_kommen_1 | "Komms" (2nd person) not in seed paradigm (listed as "kënns" incorrectly) |
| s_elo_1 | "now" dropped in idiomatic "It is time now" |
| s_nees_1 | "nach eng Kéier" (once more) — multi-word phrase, can't map |

## Notes for next batch
- Add `datt` to the `dat` map (correct Luxembourgish spelling of conjunction, vs German "dass")
- Fix kommen paradigm: "du komms" not "du kënns" in seed data
- For words with <3 usable simple sentences, write targeted sentences
  that force the lemma form (e.g. first-person singular for verbs)
- Next batch should cover lessons 6+ words (remaining ~418 senses)
