# LuxLingo — Claude Project Instructions

LuxLingo is a free iOS app for learning Luxembourgish, built for the expat community in Luxembourg. It follows a Duolingo-style gamified approach using Zipf's-law vocabulary selection. The app is a volunteer project — no revenue, no ads, free forever.

## Project Structure

```
luxlingo/
├── ios/LuxLingo/LuxLingo/          # All iOS Swift source code
│   ├── ContentView.swift           # Root: NavigationStack, splash, AppRoute enum
│   ├── LuxLingoApp.swift           # App entry point, SwiftData ModelContainer setup
│   ├── Data/
│   │   ├── ContentRepository.swift # Single data access point — ALL DB calls go here
│   │   └── UserPreferences.swift   # XP, streak (UserDefaults)
│   ├── Database/
│   │   ├── DatabaseManager.swift   # SwiftData fetch/insert primitives
│   │   └── Entities.swift          # SwiftData @Model entities (the 6 "tables")
│   ├── Models/
│   │   ├── Models.swift            # Plain Swift structs (CourseUnit, Lesson, VocabWord...)
│   │   ├── Enums.swift             # ExerciseTypeNew, AnswerFeedback, etc.
│   │   └── SeedModels.swift        # Codable structs for parsing initial_seed.json
│   ├── Services/
│   │   ├── TTSService.swift        # Sproochmaschinn.lu TTS — @MainActor singleton
│   │   ├── PronunciationService.swift  # LuxASR recording & scoring
│   │   ├── WordLookupService.swift # LOD.lu dictionary lookup with caching
│   │   └── AudioFeedbackService.swift  # Correct/incorrect tone sounds
│   ├── ViewModels/
│   │   ├── ExerciseViewModel.swift # Exercise selection, mastery, scoring logic
│   │   └── MainViewModel.swift     # Home screen units, lesson progress
│   ├── Views/
│   │   ├── HomeScreen.swift        # Lesson list, unit cards, tabs
│   │   ├── ExerciseScreen.swift    # Exercise UI orchestration
│   │   ├── LessonSummaryScreen.swift
│   │   ├── CharacterIntroScreen.swift
│   │   ├── FeedbackSheet.swift     # In-app feedback email (MFMailComposeViewController)
│   │   ├── Theme.swift             # Colors, FeedbackColors, animation presets
│   │   └── Components/
│   │       ├── ExerciseComponents.swift   # All 10 exercise type views
│   │       ├── TappableLuSentenceView.swift  # Word-tap dictionary lookup
│   │       └── SpeakerButton.swift
│   ├── Utils/EifelerRegel.swift    # Luxembourgish n-rule logic
│   └── Resources/
│       └── initial_seed.json       # ALL lesson content (v8.57) — bump version to re-seed
├── tools/
│   └── export_sentences.py         # Exports initial_seed.json → luxlingo_review.xlsx
├── content/
│   └── thematic_lessons.json       # 16 thematic A1 lessons (greetings, numbers, etc.)
├── docs/
│   └── technical_overview.md       # Full technical documentation for non-developers
├── luxlingo_review.xlsx            # Native speaker review spreadsheet
├── LuxLingo_Pitch.pptx             # ZLS funding pitch deck
├── LuxLingo_Tech.pptx              # Technical architecture deck
└── make_pitch.py                   # Script that generated LuxLingo_Pitch.pptx
```

## Tech Stack

- **Language**: Swift 5.9, iOS 17+
- **UI**: SwiftUI (declarative, `@Observable` for state)
- **Database**: SwiftData (local on-device, no backend)
- **Concurrency**: Swift async/await, TaskGroup for parallel API calls
- **Architecture**: MVVM — Views → ViewModels → ContentRepository → DatabaseManager
- **Audio**: AVFoundation (playback + recording)
- **External APIs**: Sproochmaschinn.lu (TTS), LOD.lu (dictionary), LuxASR (pronunciation scoring)

## SwiftData Entities (the database)

Six `@Model` classes in `Entities.swift`. **Critical rule: always add new fields with a class-body default value** to enable automatic lightweight migration without breaking existing installs.

```
VocabularyEntity   surface_id(PK), lemma_id, word_lu, gender/pos, lod_audio_url
SensesEntity       sense_id(PK), surface_id(FK), translations, pos, tags(=pos legacy), paradigm(JSON), is_golden_key
SentencesEntity    sentence_id(PK), text_lu, text_en, sense_ids(CSV), cloze_index, exact_form, difficulty
CurriculumEntity   lesson_id(PK), title_en, core_senses(CSV), lesson_type(core/bonus), unit_index
LessonStatusEntity lesson_id(PK), is_completed, has_started, mastery
UserProgressEntity composite_key(PK), sense_id, mastery(0-20), exposure, cloze_exposure
```

**Important**: `SensesEntity.tags` stores the POS value (e.g. "VRB", "SUBST+M") — this is a legacy naming quirk. The newer `SensesEntity.pos` field mirrors it as of seed v8.58+.

## Seed File

`initial_seed.json` (v8.57) is bundled in the app and loaded into SwiftData on first install. **To deploy content changes**: bump `"version"` in the JSON — the app detects a newer version and re-seeds on next launch. Users must delete and reinstall the app to get a fresh seed during development.

Current counts: 468 vocabulary · 469 senses · 7,662 sentences · 70 core lessons · 4 bonus lessons · 25 article exercises

## Key Architecture Decisions

### Performance: Bulk Queries
`MainViewModel.loadUnits()` uses exactly 5 bulk DB queries, then does everything else in-memory via dictionaries. Never add per-lesson or per-sense individual DB queries inside `loadUnits()` — this was the cause of 1000+ query slowdowns.

```
getAllCurriculum() + getAllSenses() + getAllVocabulary() + getAllUserProgress() + getAllLessonStatuses()
→ build in-memory dicts → compute all 70 lessons without further DB calls
```

### Audio
- **Verbs**: always use TTS (Sproochmaschinn.lu) — LOD.lu verb audio includes compound entry titles
- **Non-verbs**: prefer LOD.lu audio (more natural), fall back to TTS
- **POS detection**: `SensesEntity.tags.hasPrefix("VRB") || tags == "VERB"`
- **AVAudioSession**: use `.duckOthers` NOT `.notifyOthersOnDeactivation` on deactivate (avoids restarting car radio)

### Navigation
`ContentView` has a single `NavigationStack` with typed `AppRoute` enum (`.exercise(lessonId:)`, `.review`). `ExerciseScreenHost` wraps `ExerciseScreen` to prevent ViewModel recreation on re-renders.

### Mastery & Exercise Selection
- Mastery range: 0 (unseen) → 20 (mastered)
- Exercise type escalates with mastery: Reading/Flashcard (0-2) → MCQ/Listening (2-5) → Cloze/Jumble/Dictation (6-12) → Pronunciation/NRule/Conjugation (13+)
- Sentence selection: prioritise unmastered senses → filter by difficulty → apply recency buffer of 8 → prefer `exact_form=true` for lessons 1–4
- Review queue: 3 buckets — 60% lowest mastery, 20% medium, 20% random

## Content Data Model

Luxembourgish uses lemma/surface/inflected form distinction:
- **Lemma** (`lemma_id`): root concept — "sinn" (to be)
- **Surface form** (`word_lu`): dictionary entry — "sinn"  
- **Inflected form**: what appears in sentence at `cloze_index` — "ass" (3rd person sg)
- `exact_form: false` means the word in the sentence is conjugated/inflected

The Excel reviewer needs the **surface form from cloze_index**, not `word_lu`. The export script uses `text_lu.split()[cloze_index]` for this.

## Lesson Content & Content Pipeline

### Where the content lives

| File | What it contains |
|---|---|
| `ios/LuxLingo/LuxLingo/Resources/initial_seed.json` | **The master content file** — all vocab, senses, sentences, curriculum, article exercises. Bundled inside the iOS app. v8.57. |
| `content/thematic_lessons.json` | 16 thematic A1 lessons (greetings, numbers, colours, family etc.) — assembled but not yet integrated into the app. |
| `luxlingo_review.xlsx` | Two-sheet Excel for native speaker review. Sheet 1 = all app sentences (with actual surface word at cloze_index). Sheet 2 = thematic content. |
| `sentence_generation_prompt.md` | Prompt template fed to an LLM to generate new English sentences per vocabulary word, before translation to Luxembourgish. |
| `LuxMT/still_unfixed.json` | ~229 sentences with known content issues (wrong character names etc.) not yet corrected. |
| `LuxMT/batch*.json` | Historical translation batch files (90+ batches) from the content generation pipeline — reference only. |

### Content pipeline — how sentences get into the app

The full pipeline for adding new sentences:

```
1. Generate English sentences
   → Use sentence_generation_prompt.md with any LLM
   → Output: JSON array of {sense_id, text_en} objects

2. Translate to Luxembourgish via LuxMT
   → translate_batches.py  (calls LuxMT API, injects text_lu into seed)

3. Annotate linguistic metadata
   → annotate_sentences.py  (sets cloze_index, n_rule_word_index, exact_form)

4. Add verb paradigms from LOD.lu
   → seed_paradigms.py  (fetches present tense conjugations, past participle)

5. Validate the seed
   → validate_seed.py  (checks structure, required fields, sense_id references)

6. Quality-fix known issues
   → fix_seed_quality.py  (fixes common errors: de→den n-rule, Ech hu→Ech hunn etc.)

7. Bump version in initial_seed.json and reinstall app
```

### Python scripts — content generation & validation

**Active / regularly used:**

| Script | Purpose |
|---|---|
| `validate_seed.py` | Validates `initial_seed.json` structure — checks all sense_id references, required fields, JSON integrity. Run this after any seed edits. |
| `annotate_sentences.py` | Sets `cloze_index` (which word is the target), `n_rule_word_index`, and `n_rule_form` on sentences. Uses paradigm data to find the correct form. |
| `fix_seed_quality.py` | Batch-fixes known quality issues — n-rule errors (de Auto → den Auto), Ech hu → Ech hunn normalisations, etc. |
| `seed_paradigms.py` | Fetches verb paradigms (present tense table, past participle, auxiliary) from LOD.lu and injects them as JSON into `SensesEntity.paradigm`. |
| `translate_batches.py` | Calls LuxMT API to translate English sentences → Luxembourgish and injects them into the seed. Manages batch state in `LuxMT/translate_batches_state.json`. |
| `import_sentences.py` | Imports LLM-generated English sentences, translates via LuxMT, validates, and injects into seed. Entry point for adding new sentence batches. |
| `reimport_sentences.py` | Re-translates rows from `luxlingo_review.xlsx` where the English was manually corrected. Patches seed in place. |
| `tools/export_sentences.py` | Exports seed → `luxlingo_review.xlsx` for native speaker review. Sheet 1 uses `cloze_index` to show the actual inflected word used in each sentence. |

**Quality / verification:**

| Script | Purpose |
|---|---|
| `deepl_verify.py` | Cross-checks LuxMT translations against DeepL. Flags sentences where the two translations diverge significantly (possible translation errors). |
| `apply_deepl_fixes.py` | Applies corrections from `deepl_verify.py` output — three tiers by severity (complete replacement, partial fix, flag for manual review). |
| `LuxMT/apply_review.py` | Applies fixes to sentences in `LuxMT/still_unfixed.json` — substitution, replacement, or manual override strategies. |
| `LuxMT/fix_missing_word_sentences.py` | Two-pass fix for sentences where the target Luxembourgish word is completely absent from `text_lu`. |

**Presentation / export tools (not content pipeline):**

| Script | Purpose |
|---|---|
| `make_pitch.py` | Generates `LuxLingo_Pitch.pptx` — ZLS inspirational pitch deck. |
| `generate_tech_pptx.py` | Generates `LuxLingo_Tech.pptx` — technical architecture deck. |
| `prepare_vocab_images.py` | Prepares vocabulary illustration images for the asset catalog. |

**Legacy / reference only (LuxMT/ folder):**

These were used in earlier pipeline iterations and are kept for reference:

| Script | Notes |
|---|---|
| `LuxMT/manage_generation.py` | Earlier batch management tool — superseded by `translate_batches.py` |
| `LuxMT/generate_lesson.py` | Early lesson generation script |
| `LuxMT/luxmt_batch.py` | Low-level LuxMT API batch caller |
| `LuxMT/enrich_seed_data.py` | Early enrichment pass — adds audio URLs, LOD.lu data |
| `LuxMT/verify_seed_data.py` | Earlier validation script — superseded by `validate_seed.py` |

### Running the review export

```bash
cd /Users/nv/Projects/luxlingo
python3 tools/export_sentences.py
# Regenerates luxlingo_review.xlsx
# Sheet 1: all 7,687 app sentences (lesson sentences + article exercises)
#   Columns: Lesson | Sentence ID | Word (LU) | Meaning (EN) | English |
#            Difficulty | Luxembourgish | Luxembourgish Corrected | Reviewer Notes
# Sheet 2: 619 rows of thematic content (vocab + sentences + dialogues)
```

Word (LU) shows the **actual inflected form** from the sentence (e.g. "ass", "huet"), not the base lemma — extracted via `cloze_index`. Article exercises show the correct article (e.g. "De", "Den", "D'").

## Common Tasks

### Fixing a sentence in the seed
1. Edit `initial_seed.json` — find by `sentence_id` or text
2. Bump `"version"` by 0.01
3. Delete app from iPhone → Run from Xcode to reinstall with fresh seed

### Exporting sentences for native speaker review
```bash
cd /Users/nv/Projects/luxlingo
python3 tools/export_sentences.py
# Output: luxlingo_review.xlsx (Sheet 1: app sentences, Sheet 2: thematic content)
```

### Building and installing on iPhone
- Open Xcode: `ios/LuxLingo/LuxLingo.xcodeproj`
- Select iPhone as destination → ⌘R to build and run
- Terminal builds fail (Apple ID credentials require Xcode GUI)

### Checking real build errors
SourceKit errors shown in the editor are often macOS-context noise (UIKit, SwiftData entities not visible from macOS). To see real iOS build errors:
```bash
cd ios/LuxLingo
xcodebuild -scheme LuxLingo -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep "error:"
```

## Luxembourgish-Specific Rules

- **N-rule (Eifeler Regel)**: `de` → `den` before vowel-initial or h-initial words. Logic in `Utils/EifelerRegel.swift`
- **Articles**: `de` (masc nom), `den` (masc acc + before vowels), `d'` (fem + neuter), `dem` (masc/neuter dat), `der` (fem dat)
- **"Ech hunn"** not "Ech hu" — common error in generated content, check for it
- **Verb conjugation**: "sinn" → ass (3rd sg), "hunn" → huet (3rd sg), "ginn" → gëtt (3rd sg)
- LOD.lu API is the authoritative source for Luxembourgish word data

## Things to Avoid

- **Don't call `getSentenceForLesson()` from `loadUnits()` or `getEncounteredVocab()`** — this triggers the full sentence selection algorithm for every word and causes severe lag
- **Don't add per-lesson DB queries inside loops** — use bulk fetch + in-memory dict pattern
- **Don't use `.notifyOthersOnDeactivation`** when deactivating AVAudioSession — restarts car radio via Bluetooth
- **Don't call `loadUnits()` synchronously from button handlers** — wrap in `Task { @MainActor in }` so navigation animations aren't blocked
- **Don't add SwiftData entity fields without class-body defaults** — breaks existing user installs without migration
- **Don't use `microStructures.first`** in LOD.lu parsing — must iterate all microStructures to get complete translations

## App State

- **Version**: 1.0 (App Store not yet submitted)
- **Seed version**: 8.57
- **Status**: Functional iOS app, real-device tested, pre-App Store
- **GitHub**: https://github.com/vinayarun/luxlingo (main branch)
- **Feedback email**: luxlingo.app@gmail.com
- **Target**: ZLS / Luxembourg government for modest support (~€389/year costs)

## Characters (used in all example sentences)

| Name | Age | Background |
|---|---|---|
| Marc | 8 | Boy, lives in Mecher, plays football |
| Anna | 11 | Girl, from Germany, Paul's sister, has dog Bello |
| Paul | 12 | Boy, from Germany, Anna's brother, loves cycling |
| Lena | 11 | Girl, from Belgium, kind, makes breakfast |
| Claire | 11 | Girl, top of class, loves books, has a cat |
| Natali | 5 | Girl, neighbour, already fluent in Luxembourgish |
| Här Weiss | adult | Male teacher, patient, believes anyone can learn |
| Bello | — | Anna's dog, always happy |

Sibling pairs: Marc & Claire / Anna & Paul. Natali is neighbour to Lena.
