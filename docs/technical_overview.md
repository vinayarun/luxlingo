# LuxLingo — Technical Overview

**Version:** Seed 8.57 | **Platform:** iOS (SwiftUI / SwiftData)  
**Audience:** Product manager with deep product knowledge, limited software development background

---

## 1. Introduction

This document explains how LuxLingo works under the hood — not as a user, but as a piece of software. It covers the architecture, the database, how exercises are selected, how audio works, and what happens when the app calls external services. It also explains the design decisions behind significant technical choices so that the reasoning is visible, not just the outcome.

The goal is not to turn you into a developer, but to give you a clear enough mental model that you can make informed product decisions, debug unexpected behaviour, and communicate confidently with any engineer who joins the project.

Every technical term is defined on first use. Use the glossary in Section 2 as a reference whenever you encounter an unfamiliar word.

---

## 2. Glossary of Key Terms

| Term | Plain-English Definition |
|---|---|
| **Swift** | Apple's programming language, introduced in 2014, used to write all LuxLingo iOS code. Compiled (turned into machine code before the app runs), type-safe (the compiler catches many errors before users see them), and modern. |
| **SwiftUI** | Apple's framework for building the visual interface. It is *declarative*: you describe what the screen should look like given the current state ("if loading is true, show a spinner; otherwise, show the lesson card"), and SwiftUI figures out how to draw it. You don't manually add or remove elements — you describe the desired result, and SwiftUI reconciles. |
| **SwiftData** | Apple's modern on-device database framework (introduced 2023). It stores structured data that survives app restarts — think of it as a set of spreadsheet tables that live on the user's device. No internet is required. |
| **MVVM** | Model–View–ViewModel. A way of organising code into three layers: the *View* (what the user sees), the *ViewModel* (the logic and state behind a screen), and the *Model* (the data). Explained in detail in Section 3. |
| **ViewModel** | A Swift class that holds all the state a screen needs (e.g., "which exercise is currently showing?", "what did the user type?") and contains the logic for responding to user actions. When the ViewModel's state changes, the View automatically re-draws itself. |
| **Repository pattern** | A design convention where all data access goes through a single "gatekeeper" class (the Repository). Neither Views nor ViewModels touch the database directly — they ask the Repository. This keeps all data logic in one place. |
| **async/await** | Swift's way of writing code that waits for something without freezing the app. When the app calls a network API, `await` tells Swift "pause here until the response arrives, but let the rest of the app keep running." The `async` keyword marks a function that might need to wait. |
| **API / REST API** | An Application Programming Interface is a defined way for two programs to talk to each other. A REST API is the most common type on the web: the app sends an HTTP request (like a browser loading a webpage) and receives a structured response, usually in JSON format. |
| **JSON** | JavaScript Object Notation — a lightweight text format for structured data. Looks like `{"word": "sinn", "translation": "be"}`. The seed file is JSON; API responses are JSON. |
| **Singleton** | A class with exactly one shared instance across the entire app. `TTSService.shared` and `PronunciationService.shared` are singletons — there is one audio player and one recording manager for the whole app, ensuring they don't step on each other. |
| **Actor / @MainActor** | Swift's mechanism for ensuring that code runs on the right thread. iOS has a "main thread" that handles all UI updates. `@MainActor` tells Swift "this code must always run on the main thread" — otherwise, updating the interface from a background thread can cause crashes or visual glitches. Almost all LuxLingo ViewModels and services are marked `@MainActor`. |
| **@Observable** | A Swift macro (a code-generation shortcut) that makes a class automatically notify SwiftUI when any of its properties change. When `ExerciseViewModel.uiState.promptText` changes, SwiftUI re-draws the exercise screen. No manual "notify observers" call is needed. |
| **Entity** | In a database context, an entity is a single table — one type of thing being stored. `VocabularyEntity` is a table of words; `SentencesEntity` is a table of sentences. One row in the table = one instance of that entity. |
| **Primary key / Foreign key** | A primary key is the unique identifier for a row (e.g., `sense_id = "s_sinn_1"`). A foreign key is a reference from one table to another (e.g., `SentencesEntity.senseIds` contains sense IDs that "point to" rows in `SensesEntity`). SwiftData doesn't enforce foreign key constraints, but the app treats these fields as links. |
| **Cloze** | A fill-in-the-blank exercise format. "Anna ___ e Meedchen" is a cloze exercise where the target word ("ass") is blanked out for the learner to supply. The word "cloze" comes from the linguistic term "closure." |
| **Lemma vs surface form vs inflected form** | A *lemma* is the root/dictionary form of a word (e.g., "sinn" — "to be"). A *surface form* is the word as it actually appears in a sentence, which may differ (e.g., "ass" is the surface form when "hien ass" means "he is"). An *inflected form* is any variant produced by grammar rules (conjugation, declension, n-rule application). |
| **Mastery** | LuxLingo's internal score (0–20) for how well a user knows a particular word sense. 0 = never seen, 20 = fully mastered. This score drives which exercise type is shown and feeds into the review system. |
| **Spaced repetition** | A learning technique where items are reviewed at increasing intervals — you see something soon after first learning it, then less and less frequently as you get better at it. LuxLingo's review queue approximates this with a 3-bucket system. |
| **Seed data** | The pre-built content bundled inside the app: all vocabulary, senses, sentences, lessons, and article exercises, stored in `initial_seed.json`. On first install, this file is loaded into the database. |
| **TTS (Text-to-Speech)** | A service that converts text into spoken audio. LuxLingo uses Sproochmaschinn.lu for Luxembourgish TTS. |
| **ASR (Automatic Speech Recognition)** | The reverse of TTS: a service that converts spoken audio into text (transcription). LuxLingo uses LuxASR to evaluate pronunciation exercises by transcribing the learner's recording and comparing it to the target word. |

---

## 3. High-Level Architecture

### The Restaurant Analogy

Think of the app as a restaurant:

- **The View** (what you see and tap) is the dining room: menus, plates, the waiter taking your order. It presents information and relays your actions.
- **The ViewModel** is the kitchen manager: it decides what dish to prepare next, tracks what's been ordered, and coordinates the kitchen. When you say "I want the cloze exercise," the ViewModel handles that.
- **The Repository** is the pantry + chef team: a single point of truth for all ingredients (data). The kitchen manager asks the pantry for ingredients; it doesn't wander into the storage room itself.
- **SwiftData** (the database) is the cold storage behind the pantry: everything persists there even when the restaurant closes for the night.
- **Services** are specialist suppliers: a dedicated audio delivery van (TTSService), a pronunciation evaluator (PronunciationService), a dictionary courier (WordLookupService).

### The Four Layers in Code

```
┌─────────────────────────────────────────┐
│  Views (SwiftUI)                        │
│  HomeScreen · ExerciseScreen · ...      │
│  What the user sees and taps            │
├─────────────────────────────────────────┤
│  ViewModels (@Observable)               │
│  MainViewModel · ExerciseViewModel      │
│  State + logic for each screen          │
├─────────────────────────────────────────┤
│  ContentRepository / DatabaseManager   │
│  Single gatekeeper to all data          │
├─────────────────────────────────────────┤
│  SwiftData (on-device SQLite)           │
│  7 entity tables — survives restarts    │
└─────────────────────────────────────────┘
         ↕ Services (cross-cutting)
  TTSService · PronunciationService
  WordLookupService · AudioFeedbackService
```

**Views** are declared in SwiftUI. They observe their ViewModel's state. When state changes, SwiftUI re-draws exactly the parts that are affected — not the whole screen.

**ViewModels** are marked `@Observable` and `@MainActor`. They own `ExerciseUiState` (a single struct holding everything the exercise screen needs at any moment) and respond to user actions like `onOptionSelected(_:)` or `checkAnswer()`.

**ContentRepository** is the single source of truth for all data reads and writes. It sits between ViewModels and the database, and owns the seeding logic. Neither a View nor a ViewModel ever touches SwiftData directly.

**DatabaseManager** wraps SwiftData's `ModelContext` (the object that talks to the database file on disk) and provides named methods like `getSense(_:)`, `getAllCurriculum()`, and `insertUserProgress(_:)`. It is used only by ContentRepository.

**Services** are singletons:
- `TTSService.shared` — Luxembourgish text-to-speech playback
- `PronunciationService.shared` — recording, submission, and polling for pronunciation scores
- `WordLookupService.shared` — dictionary lookups for the word-tap feature
- `AudioFeedbackService.shared` — short tones and haptics for correct/wrong answers

---

## 4. The Database

### What SwiftData Is

SwiftData is Apple's way of storing structured data permanently on the device. You define your data as Swift classes decorated with `@Model`, and SwiftData handles the rest: creating the underlying storage (a SQLite database file), saving and loading records, and keeping everything consistent.

Think of it as a set of spreadsheets that live inside the app. Each `@Model` class is one sheet (a table). Each instance of that class is one row. SwiftData writes these rows to disk so they're still there after the app restarts or the phone is turned off.

SwiftData does **not** require an internet connection. All lesson content, progress, and curriculum data live entirely on-device.

### The Seven Tables

LuxLingo has seven entities. Together they describe what the app knows (content) and what the user has done (progress).

---

#### `VocabularyEntity` — One row per Luxembourgish word

Each row represents a single dictionary entry — one headword.

| Field | Type | Description |
|---|---|---|
| `surfaceId` | String (unique key) | Unique identifier for this word, e.g. `"w_sinn"` |
| `lemmaId` | String | Identifier of the root concept, e.g. `"l_sinn"` |
| `wordText` | String | The Luxembourgish word itself, e.g. `"sinn"` |
| `components` | String? | Optional morphological breakdown (rarely used) |
| `phonetic` | String? | Optional phonetic transcription |
| `audioRef` | String? | Legacy audio reference field (largely superseded by lodAudioUrl) |
| `lodAudioUrl` | String? | URL to a pronunciation audio file at lod.lu, e.g. `"https://lod.lu/uploads/AAC/sinn1.m4a"` |

The `lodAudioUrl` field matters a lot: it is the URL the app fetches when a speaker button is tapped for a non-verb word. The LOD audio was recorded by native speakers and sounds natural.

In the seed JSON, the `gender` field stores a part-of-speech tag for non-nouns (e.g. `"VRB"`, `"PREP"`, `"CONJ"`) and M/F/N for nouns. The app reads this from the senses table (`pos`) rather than from vocabulary.

---

#### `SensesEntity` — One row per meaning of a word

A word can have multiple meanings (a "word" like "bank" means both a financial institution and the side of a river). Each distinct meaning is a separate row in this table.

| Field | Type | Description |
|---|---|---|
| `senseId` | String (unique key) | Identifier for this specific meaning, e.g. `"s_sinn_1"` |
| `surfaceId` | String | Links back to `VocabularyEntity` (which word this meaning belongs to) |
| `translations` | String | English translation, e.g. `"be"` |
| `altEn` | String? | Alternative English translation (for words with near-synonym meanings) |
| `tags` | String | Part-of-speech tag — legacy field name, but stores the POS value (same as `pos`) |
| `pos` | String | Part of speech: `VRB`, `VRB+MOD`, `SUBST+M`, `SUBST+F`, `SUBST+N`, `ADJ`, `PREP`, `CONJ`, etc. |
| `isGoldenKey` | Bool | Marks this as a high-frequency "must know" word |
| `isPicturable` | Bool | Whether a visual image exists for this concept |
| `falseFriend` | String? | English word that looks similar but means something different (a "false friend") |
| `paradigm` | String? | JSON blob with the verb's present tense conjugation, e.g. `{"present": ["ech sinn", "du bass", ...]}` |

The `paradigm` field is only populated for verbs. It stores the full present-tense conjugation table as a JSON string, which the app decodes to show conjugation chips on flashcards and to power the Paradigm Picker exercise type.

---

#### `SentencesEntity` — One row per example sentence

Every exercise is grounded in a real sentence. This table holds all 7,662 of them.

| Field | Type | Description |
|---|---|---|
| `sentenceId` | String (unique key) | Unique identifier, e.g. `"sent_0042"` |
| `textLu` | String | The Luxembourgish sentence, e.g. `"Anna ass e Meedchen."` |
| `textEn` | String | The English translation, e.g. `"Anna is a girl."` |
| `senseIds` | String | Comma-separated list of sense IDs that this sentence practices |
| `clozeIndex` | Int | The word position (0-indexed) of the target word — so the app knows which word to blank out in a cloze exercise |
| `exactForm` | Bool | `true` if the target word at `clozeIndex` is in its base dictionary form; `false` if it's conjugated or otherwise inflected |
| `difficulty` | String | `"simple"`, `"intermediate"`, or `"advanced"` |
| `nRuleWordIndex` | Int? | If this sentence has an n-rule application, the word index where it occurs |
| `nRuleForm` | String? | The n-rule form of the word as it appears in the sentence (with the trailing -n already dropped) |
| `lexCoverage` | Double | Lexical coverage metric (not used at runtime) |
| `synDensity` | Double | Syntactic density metric (not used at runtime) |
| `isHandcrafted` | Bool | Whether this sentence was manually written (vs. AI-generated) |

The `clozeIndex` field is the key to how blanks work. For `"Anna ass e Meedchen."`, `clozeIndex = 1` (the second word, zero-indexed), so `"ass"` gets blanked. The `exactForm = false` flag tells the app that "ass" is a conjugated form of "sinn" — important for early lessons, where the app prefers `exactForm = true` sentences.

---

#### `CurriculumEntity` — One row per lesson

There are 70 core lessons and additional bonus lessons (4 per unit, unlocked after completing 4 core lessons in a unit).

| Field | Type | Description |
|---|---|---|
| `lessonId` | String (unique key) | e.g. `"lesson_1"`, `"lesson_42"`, `"bonus_unit1_cafe"` |
| `titleEn` | String | Display name, e.g. `"Lesson 1 — I, Be & Have"` |
| `coreSenses` | String | Comma-separated sense IDs that are the core vocabulary for this lesson |
| `secondarySenses` | String? | Optional additional senses that appear in sentences but aren't primary targets |
| `lessonType` | String | `"core"` or `"bonus"` |
| `unitIndex` | Int | Which unit this lesson belongs to (0-indexed; 10 units total for core lessons) |
| `orderIndex` | Int | Sort order for display |
| `themeTag` | String? | For bonus lessons: stores the scene image name |
| `situationTag` | String? | For bonus lessons: the conversational situation (e.g. `"cafe"`, `"market"`) |
| `prereqs` | String? | Prerequisite lesson IDs (not currently enforced) |

The `unitIndex` for core lessons is derived at seeding time: lesson N belongs to unit `(N-1) / 7`. So lessons 1–7 are Unit 1, lessons 8–14 are Unit 2, and so on.

---

#### `LessonStatusEntity` — One row per lesson the user has touched

Tracks the user's relationship with each lesson.

| Field | Type | Description |
|---|---|---|
| `lessonId` | String (unique key) | Links to `CurriculumEntity` |
| `titleEn` | String | Lesson title (denormalized for convenience) |
| `isCompleted` | Bool | Whether the user has finished this lesson |
| `hasStarted` | Bool | Whether the user has opened this lesson at all |
| `mastery` | Int | Aggregate mastery score for this lesson |
| `completionPercentage` | Double | Percentage completion (0.0–100.0) |
| `orderIndex` | Int | Sort order |

The `hasStarted` field exists to prevent a subtle UI bug: progress rings should only appear on lessons the user has actually opened. Without this field, a lesson where the user happened to practise a word incidentally (via another lesson's sentence) could show a non-zero ring even though they'd never opened it. `hasStarted` is set to `true` the moment the user taps into a lesson; the ring only draws if `hasStarted == true`.

**Schema evolution note:** `hasStarted` was added after the initial release, with a default value of `false` declared in the Swift class body. This is the key to pain-free database updates in SwiftData — if you declare a default value at the class level, SwiftData automatically gives that default to all existing rows when the app updates. No complex migration script is required. This is how new fields can be added to any entity without breaking users who already have the app installed.

---

#### `UserProgressEntity` — One row per word the user has practised

One row for every word sense the user has ever seen in any exercise.

| Field | Type | Description |
|---|---|---|
| `compositeKey` | String (unique key) | `"userId\|senseId\|surfaceId"` — constructed at insertion time |
| `userId` | String | Always `"default_user"` (no accounts) |
| `senseId` | String | Which word sense this tracks |
| `surfaceId` | String | Which word form (links to `VocabularyEntity`) |
| `mastery` | Int | 0–20 score. 0 = never seen, 20 = fully mastered |
| `exposure` | Int | Total number of exercises seen for this word |
| `clozeExposure` | Int | Number of cloze (fill-in-the-blank) exercises completed for this word |
| `lastError` | String? | The last wrong answer typed (for diagnostics) |
| `fsrsData` | String? | Reserved for a future FSRS-based spaced repetition upgrade |

The `compositeKey` solves a limitation of SwiftData: it doesn't support true composite primary keys (unique constraints across multiple columns). The solution is to build the key as a string and mark it unique: `"default_user|s_sinn_1|w_sinn"`. This guarantees one progress row per user-sense-surface combination.

---

#### `ArticleExerciseEntity` — One row per article-choice exercise

A specialised exercise type where the learner picks the correct Luxembourgish article (definite/indefinite, nominative/dative/accusative) for a noun in a sentence.

| Field | Type | Description |
|---|---|---|
| `exerciseId` | String (unique key) | Unique identifier |
| `senseId` | String | The noun sense this exercise tests |
| `textLu` | String | The sentence with the article blanked as `"___"` |
| `textEn` | String | English translation |
| `articleIndex` | Int | Word position of the missing article |
| `correct` | String | The correct article, e.g. `"de"` or `"eng"` |
| `options` | String | JSON array of all options, e.g. `["de","den","dem","e"]` |
| `ruleHint` | String | A plain-English hint about which grammatical rule applies |
| `difficulty` | String | `"simple"`, `"intermediate"`, or `"advanced"` |

---

## 5. Content Data Model

### The Four-Tier Hierarchy

LuxLingo organises its content in four nested levels:

```
Lemma (root concept)
  └── Surface form (dictionary entry / word)
        └── Sense (one meaning of that word)
              └── Sentences (example contexts)
```

### Worked Example: "sinn" (to be)

**Lemma:** The abstract root concept "to be" — identified as `"l_sinn"`.

**Surface form:** The dictionary entry `"sinn"` — stored in `VocabularyEntity` with `surfaceId = "w_sinn"`. This is the word as you'd look it up. The LOD audio URL points to a native speaker recording of `"sinn"`.

**Sense:** `SensesEntity` row `"s_sinn_1"` connects `"w_sinn"` to the meaning `"be"`. The paradigm field stores:

```json
{
  "present": [
    "ech sinn",
    "du bass",
    "hien/si/et ass",
    "mir sinn",
    "dir sidd",
    "si sinn"
  ]
}
```

**Sentences:** Many sentences in `SentencesEntity` reference `"s_sinn_1"`. Some use the base form:
- `"Ech sinn do."` with `clozeIndex = 1`, `exactForm = true` (the word at index 1 is "sinn" — unchanged)

Others use a conjugated form:
- `"Anna ass e Meedchen."` with `clozeIndex = 1`, `exactForm = false` (the word at index 1 is "ass", which is the 3rd-person singular form of "sinn")

The app uses `exactForm` to decide which sentences to show to beginners. In lessons 1–4, only `exactForm = true` sentences are shown — the learner sees the word in its base dictionary form. From lesson 5 onward, conjugated forms are introduced.

### The Seed File

`initial_seed.json` is a JSON file bundled inside the app binary (in the Resources folder). It is the source of all lesson content. Current statistics:

| Content type | Count |
|---|---|
| Vocabulary entries (surface forms) | 468 |
| Senses (word meanings) | 494 |
| Example sentences | 7,662 |
| Core lessons | 70 |
| Bonus lessons | 4 |
| Article exercises | 25 |
| Seed file version | 8.57 |

**How seeding works:** On every launch, the app checks the `version` number stored in `initial_seed.json` against the version stored in `UserDefaults` (a small key-value store separate from SwiftData). If the bundled version is higher than what was last loaded, the app wipes all content tables and reloads from the seed file. User progress is also wiped in this process — content updates and progress resets are coupled.

The seeding process is careful about performance: it saves to disk in batches of 500 sentences and yields to the main thread between batches (using `await Task.yield()`) so the app's watchdog timer is never triggered. On an average device, seeding 7,662 sentences takes a few seconds, which is why the splash screen plays for 2.5 seconds — seeding runs concurrently during the animation.

**Why a seed file rather than a server:** The seed file approach means the app works entirely offline, content doesn't require a backend, and there's no GDPR concern about sending lesson content over the network. The tradeoff is that updating content requires a new App Store submission (to ship a new binary carrying the updated seed file), though the content itself can change without any Swift code changes.

---

## 6. How Exercises Work

### Exercise Selection — Step by Step

When a lesson screen opens, `ExerciseViewModel.loadNextExercise()` runs the following logic:

**Step 1 — Detect the phase.** The ViewModel checks how many of the lesson's core senses the user has *never* seen (mastery = 0). If any exist, the session is in the "Introduction" phase: these unseen words are the highest priority.

**Step 2 — Select the target sense.** In the Introduction phase, the app takes up to 3 unseen senses and shuffles them, choosing one. This mild randomisation prevents always introducing words in the same order. Once all core senses have been seen at least once (mastery ≥ 1), the app picks from unmastered senses (mastery < 20), with a forced switch if the same word has appeared 3 times in a row.

**Step 3 — Fetch a sentence.** The Repository's `getSentenceForLesson` function finds all sentences that practice the target sense. It filters by difficulty (see below) and checks that the sense is the *primary* target of the sentence — not just a secondary word that happens to appear.

**Step 4 — Apply the difficulty filter.** The allowed difficulty tier shifts as lessons progress:
- Lessons 1–15: "simple" sentences only
- Lessons 16–35: randomly "simple" or "intermediate"
- Lessons 36–50: randomly "intermediate" or "advanced"
- Lessons 51+: "intermediate" and "advanced" mixed

**Step 5 — Apply the recency buffer.** The last 8 sentences seen are stored in `recentSentenceIds`. The app excludes these from the pool, preventing immediate repetition. The buffer scales dynamically: if the pool only has 6 sentences, the buffer size shrinks to half the pool size so the learner isn't stuck.

**Step 6 — Apply the exact-form filter for early lessons.** For lessons 1–4, the app strongly prefers sentences where `exactForm = true` (the word appears in its base dictionary form, unchanged). If all exact-form sentences are in the recency buffer, the app ignores the recency buffer rather than showing a conjugated form — "better to repeat than to confuse beginners."

**Step 7 — Select the exercise type** (see below).

### Exercise Type Selection

The exercise type is chosen based on the word's current mastery score, with probabilistic overrides layered on top:

**Base type by mastery:**

| Mastery range | Base exercise type |
|---|---|
| 0 | Flashcard — "New word!" card showing the word and its meaning |
| 1–5 | Reading — show the sentence, highlight the target word, prompt to read aloud |
| 6–9 | Multiple Choice — sentence with a blank, four options |
| 10–14 | Matching or Jumbled English |
| 15–19 | Jumbled Luxembourgish — arrange scrambled tokens into the correct sentence |
| 20 | Cloze — type the missing word |

**Probabilistic overrides** (layered on top of the base type, checked in order):

| Condition | Probability | Exercise added |
|---|---|---|
| Mastery 8–18, sentence has n-rule candidate | 30% | N-Rule Hunter |
| Mastery 12–25 | 20% | Speed Run (Zipf flash card) |
| Mastery 4–15 | 22% | Listening Comprehension (hear the word, pick English meaning) |
| Mastery 8–22 | 18% | Audio Dictation (hear the word, type it in Luxembourgish) |
| Mastery 8–22, sense has paradigm, sentence uses conjugated form | 25% | Conjugation Match (which lemma is this conjugated form of?) |
| Mastery 12–25, sense has paradigm | 20% | Paradigm Picker (given the infinitive, choose the conjugation for a pronoun) |
| Mastery > 3, noun sense, article exercise exists | 15% | Article Choice |
| Mastery > 5, not review mode, not intro phase | 12% | Pronunciation Practice (once per sense per session) |

This layered system means the exercise variety increases as a learner gets better at a word — early exposures are forgiving (flashcards, reading), while advanced learners face more demanding challenges.

### Mastery Scoring

Each exercise result changes the mastery score for the target sense. Mastery never goes below 0 and is capped at 20.

**Mastery weight per exercise type (correct answer):**

| Exercise type | Mastery gain |
|---|---|
| Reading / Flashcard | +1 |
| Matching | +3 |
| Multiple Choice | +4 |
| Listening Comprehension | +4 |
| Article Choice | +4 |
| Speed Run | +5 |
| Conjugation Match | +5 |
| Pronunciation Practice | +5 |
| Audio Dictation | +6 |
| N-Rule Hunter | +6 |
| Paradigm Picker | +6 |
| Jumbled (LU or EN) | +8 |
| Cloze | +10 |
| Wrong answer (any type) | −2 |

**First-exposure boost:** If a word has mastery = 0 and the exercise result would normally add just 1 point, the app bumps it to 3. This ensures a word isn't stuck at near-zero after a single reading encounter.

**Secondary sense credit:** When a sentence is shown, other senses from the same lesson that appear in that sentence also receive a smaller mastery credit — 1 or 2 points depending on the exercise type. Words that have never been seen (mastery = 0) receive triple credit on their first secondary encounter.

**Lesson completion and Rapid Fire:** When all core senses reach mastery ≥ 20, the lesson doesn't end immediately. Instead, the app launches a "Rapid Fire" round: 8 speed-run cards (one per core sense), shuffled. This is the end-of-lesson burst before the summary screen appears.

---

## 7. Performance — How the App Stays Fast

### The Problem

The home screen displays all 70 lessons simultaneously — their titles, objectives, progress rings, word counts, and unit groupings. Naively, building this would require:
- 70 calls to fetch lesson senses
- Hundreds of individual sense lookups
- 70 progress queries
- 70 status queries

That's potentially 1,000+ database queries on a single screen refresh. On an iPhone, this causes a noticeable stall whenever the user returns from a lesson.

### The Solution: Bulk Fetch with In-Memory Lookups

`MainViewModel.loadUnits()` makes exactly **5 database queries** — one for each table it needs — and then does all the computation in memory:

```
Query 1: getAllCurriculum()   → all 74 lesson records
Query 2: getAllSensesMap()    → all 494 senses as a dictionary
Query 3: getAllVocabMap()     → all 468 vocabulary entries as a dictionary
Query 4: getAllProgressMap()  → all progress rows as a dictionary
Query 5: getAllLessonStatuses() → all lesson status rows
```

After these 5 queries, every lesson's data is assembled by looking up keys in in-memory dictionaries (a dictionary lookup is essentially instant, regardless of how many items it contains — this is what "O(1) access" means). The entire home screen — all 70 lessons with their progress rings, objectives, and word counts — is built without a single additional database query.

**The librarian analogy:** The difference between fetching one book at a time for 1,000 requests versus pulling an entire shelf of books, then handing them out from the shelf. The first approach requires 1,000 trips to the storage room; the second requires one trip and 1,000 hand-offs from the table.

### Other Performance Decisions

**Lazy vocab loading.** Each unit card on the home screen has a scene image (a Luxembourgish landscape). When the user taps that image, the full vocabulary list for the unit appears. The vocabulary query is intentionally deferred to that tap moment — not triggered when the card first renders on screen. This keeps the initial home screen load fast.

**Deferred `loadUnits()`.** `MainViewModel.init()` does not call `loadUnits()` directly. Instead, it spawns a `Task` (a small asynchronous job):
```swift
Task { @MainActor [weak self] in self?.loadUnits() }
```
This means the splash screen animation starts rendering before any database work begins. The `loadUnits()` call happens on the next "tick" of the event loop — after the first frame of the animation has drawn.

**Non-blocking navigation back.** When a user presses Back after completing a lesson, the `onBack` closure does two things: removes the lesson from the navigation stack (triggering the Back animation), and schedules `loadUnits()` in a Task. The animation runs fully unblocked. The home screen refreshes with updated progress once the animation completes.

---

## 8. External Services and APIs

### Sproochmaschinn.lu — Text-to-Speech (TTS)

**What it is:** A Luxembourgish text-to-speech service maintained by the University of Luxembourg. When the app needs to speak a Luxembourgish word or sentence aloud (and a LOD audio URL isn't available or isn't appropriate), it calls this API.

**When it's called:**
- Always for verbs (LOD audio for verbs reads the full dictionary entry title aloud, which sounds unnatural for a language learner context)
- For any word or sentence when no LOD URL is available
- For full sentence playback in listening comprehension exercises

**How it works (four-step protocol):**

1. **Open a session** (`POST /api/session`) — the server assigns a session ID. Sessions stay valid for 9 minutes; the app reuses the same session ID across multiple requests and creates a new one only when the old one expires.

2. **Submit the text** (`POST /api/tts/{sessionId}`) — the app sends the Luxembourgish text as JSON and receives a `request_id`.

3. **Poll for the result** (`GET /api/result/{requestId}`) — the app checks every second (with a slightly shorter first check at 600ms), up to 25 times, waiting for `"status": "completed"`.

4. **Decode and play the audio** — the response includes base64-encoded WAV audio. The app decodes this binary data and plays it through `AVAudioPlayer`.

The app plays TTS audio at 85% of normal speed (`speechRate = 0.85`) — 15% slower than natural speech — to make it easier to follow for learners.

---

### LOD.lu — Luxembourgish Online Dictionary

**What it is:** The Luxembourgish Online Dictionary (`lod.lu`), the official digital dictionary of the Luxembourgish language. LuxLingo uses it for two purposes: word lookup (when a user taps any word in a sentence) and for pre-recorded native speaker audio.

**Audio:** The `lod_audio_url` field in `VocabularyEntity` points to an AAC audio file hosted on lod.lu. These are native speaker recordings, and the app plays them directly via URL for most non-verb words. No API call is needed for audio — it's just fetching a file.

**Word lookup API (the "tap a word" feature):** When a user taps a word, `WordLookupService` makes two API calls:

1. **Search** (`GET /api/en/search?query={word}&lang=lb`) — returns a list of dictionary entry candidates with their article IDs and part-of-speech tags.

2. **Fetch entry** (`GET /api/en/entry/{articleId}`) — returns the full dictionary entry, including all meanings (`microStructures`), translations, and grammatical information.

The service scores candidates in order of relevance:
- Direct lemma match (the searched word exactly matches the dictionary headword)
- Base-form match (e.g. "grousse" starts with "grouss", so "grouss" is a likely base form)
- Verb conjugation match (e.g. "ass" is flagged as a verb form matching "sinn")

Multiple article IDs are fetched **in parallel** using Swift's `withTaskGroup` — like sending multiple waiters to different tables at the same time rather than one at a time. All translations from all matching entries are combined and deduplicated. Results are cached in memory for the session so tapping the same word twice is instant.

**Contraction handling:** Some short Luxembourgish words are contracted forms of longer words. The service maintains a small mapping:
- `"a"` → look up `"an"` (the conjunction/preposition)
- `"am"` → look up `"an"` (the preposition "an dem", "in the")
- `"ass"` → look up `"sinn"` (3rd-person singular of "to be")

---

### LuxASR — Automatic Speech Recognition / Pronunciation Scoring

**What it is:** A speech recognition service from the University of Luxembourg specialised in Luxembourgish. LuxLingo uses it to evaluate pronunciation exercises.

**When it's called:** After a user records a pronunciation exercise and taps Submit. The audio file is sent to LuxASR in the background.

**Audio format requirements:** LuxASR requires a specific format: 16kHz sample rate, mono (one channel), 16-bit linear PCM WAV. These settings are configured in `PronunciationService.startRecording()`. The recording is saved to the app's Documents folder (a stable location — iOS clears the temporary folder too aggressively for in-flight recordings).

**How scoring works:**
1. The WAV file is sent to `POST /asr2?language=lb&diarization=Disabled&outfmt=text` — a job is queued and a `job_id` is returned.
2. The service polls every 3 seconds for status: `GET /v3/asr/jobs/{jobId}`.
3. When status is `"completed"`, the transcription is fetched: `GET /v3/asr/jobs/{jobId}/result`.
4. The app computes a score using normalised Levenshtein edit distance (a measure of how many character changes would turn one string into another): `score = 100 - (editDistance / maxLength × 100)`. A perfect match scores 100; completely wrong scores 0.

**Persistence across app restarts:** Pending scoring jobs are stored in `UserDefaults`. If the user closes the app before the score arrives, the polling resumes the next time the app opens. Completed results are stored and displayed on the lesson summary screen the next time the user finishes a lesson.

**Timing:** The pronunciation score arrives asynchronously, often after the exercise screen has moved on to the next question. The `PronunciationService` stores the result in `newResultAvailable`, and `ExerciseViewModel` polls this during the next exercise load. The score is surfaced on the lesson summary screen, not as an immediate in-line result.

---

### LuxMT — Machine Translation (Content Pipeline Only)

LuxMT is a Luxembourgish machine translation service used offline during content creation — it generates and validates sentence translations when building new seed content. It is not called at runtime by the iOS app and has no impact on app performance or user experience.

---

## 9. The Audio System

iOS has strict rules about audio: an app must declare its intentions regarding audio via `AVAudioSession` before recording or playing. The two modes the app uses are:

- **`.playback` with `.duckOthers`** — used by TTSService. The app plays audio; background music/podcasts automatically duck to ~20% volume and restore when the app's audio ends. This is the same behaviour as Google Maps navigation audio.
- **`.playAndRecord` with `.duckOthers`** — used by PronunciationService. The app both records and plays audio during a pronunciation exercise.

### TTSService

A singleton (`TTSService.shared`). All Luxembourgish speech (TTS and LOD audio) passes through this service. Key behaviours:

- **Toggle on re-tap:** Tapping a speaker button while audio is playing stops playback immediately. A second tap on the same button restarts.
- **Prevents overlap:** If audio is already loading or playing, new requests are silently ignored. Only one sound plays at a time.
- **Background audio courtesy:** When audio finishes, the service calls `setActive(false)` — this signals iOS (and via iOS, other apps like Spotify or Podcasts) that the audio session is deactivated, which triggers full volume restoration. Crucially, it does *not* send `.notifyOthersOnDeactivation` — this avoids triggering car radio autoplay via Bluetooth.
- **Playback speed:** All audio plays at 85% of normal speed via `AVAudioPlayer.enableRate` / `player.rate`.

### PronunciationService

A singleton (`PronunciationService.shared`) that manages the full recording and scoring lifecycle.

- **Recording to Documents folder:** The recording URL is constructed at recording-start time and stored immediately. iOS's temp directory is cleaned up aggressively; the Documents folder is stable and appropriate for user-generated content.
- **Amplitude visualiser:** A timer fires 16 times per second during recording. Each tick reads the microphone's average power level (in decibels), maps it to a 0–1 range, and appends it to a 14-element rolling array. The exercise screen's waveform visualiser reads this array.
- **Auto-stop:** When the elapsed recording time exceeds `maxDuration`, `stopRecording()` is called and `autoStopFired` is set to `true`. The exercise view observes this property and transitions the UI phase automatically.
- **Persistence:** Pending jobs and completed results are serialised to JSON and stored in `UserDefaults`. On launch, the service reloads this state and resumes polling if any jobs are outstanding.

### AudioFeedbackService

A singleton (`AudioFeedbackService.shared`) for short feedback tones and haptics:

- Correct answer: a tone + UINotificationFeedbackGenerator success haptic
- Wrong answer: a tone + error haptic
- Reading exercise: a softer version (30% volume) of the correct tone + light impact haptic
- Matching complete: full correct tone + success haptic

The tone delegate also deactivates the audio session when a short tone finishes, signalling background apps to restore volume.

### Microphone Permission

iOS requires explicit user permission to use the microphone. `PronunciationService.startRecording()` calls `AVAudioApplication.requestRecordPermission()`. If the user has previously denied permission, this call returns `false` immediately (iOS will not re-prompt). The exercise screen detects this state and shows an inline message with a deep link to the Settings app.

---

## 10. Word Lookup — The Dictionary Tap Feature

When a user taps any word in a Luxembourgish sentence, a dictionary popup appears. Here is the full flow through `WordLookupService.lookup(word:)`:

**Step 1 — Clean the word.** Strip punctuation (periods, commas, question marks) and lowercase it. `"Anna ass e Meedchen."` → tap "ass" → cleaned key is `"ass"`.

**Step 2 — Check the cache.** If this word was looked up in this session, return the cached result instantly. No network call needed.

**Step 3 — Check the "not found" set.** If the word was previously looked up and returned nothing, return `nil` immediately.

**Step 4 — Check the contraction map.** If the word is in the known contraction map (`"ass"` → `"sinn"`), use the mapped form for the API lookup. The result is displayed as the base word's meaning.

**Step 5 — Search the LOD API.** `GET /api/en/search?query=sinn&lang=lb` returns a list of dictionary candidates. Each entry has an `article_id`, a `word_lb` (the headword), a `pos` (part of speech), and a `matches` array (inflected forms).

**Step 6 — Score and filter candidates.** The service ranks results:
1. Direct lemma matches (where `word_lb == lookup_word`) → highest priority
2. Base-form matches (where `word_lb` is a prefix of the query, ≥4 characters, single word) → handles inflected adjectives like "grousse" → "grouss"
3. Verb conjugation matches (entries where `pos` contains "VRB" and there are verb form matches) → handles "ass" → "sinn"
4. Fallback: single-word entries from the results, up to 2

**Step 7 — Fetch all entries in parallel.** Using Swift's `withTaskGroup`, all matching article IDs are fetched simultaneously. The response for each entry contains `microStructures` → `grammaticalUnits` → `meanings` → `targetLanguages.en.parts`. All translation strings are extracted from all levels.

**Step 8 — Deduplicate and return.** Translations are combined, lowercased for comparison, and deduplicated (preserving order). The result is cached and displayed in the popup.

**An early bug, now fixed:** The original implementation only read the first `microStructure` of each dictionary entry. Many Luxembourgish words have multiple microStructures (e.g. a verb used transitively, intransitively, and reflexively). The fix iterates all microStructures, giving complete translation coverage.

---

## 11. Navigation and App Flow

### The Navigation Model

LuxLingo uses a `NavigationStack` — a SwiftUI component that maintains a stack of screens. The stack is driven by a typed enum called `AppRoute`:

```swift
enum AppRoute: Hashable {
    case exercise(lessonId: String)
    case review
}
```

- **Tapping a lesson** appends `.exercise(lessonId: "lesson_5")` to the navigation path → the exercise screen pushes onto the stack.
- **Tapping Back** removes the last entry from the path → the exercise screen pops off with the standard slide-back animation.
- **Tapping the Review card** appends `.review` to the path → the same `ExerciseScreenHost` is used, but initialised in review mode.

This approach means the entire navigation state is a simple array of `AppRoute` values. It is easy to inspect, easy to reset (clear the array), and type-safe (you can't accidentally navigate to a non-existent route).

### ExerciseScreenHost

`ExerciseScreenHost` is a wrapper view whose sole purpose is to prevent `ExerciseViewModel` from being created more than once. SwiftUI can sometimes re-create views when the navigation stack re-renders. Without the host, the ViewModel (and all the exercise state: current sentence, mastery progress, recent sentence buffer) would be reset mid-lesson. The host holds the ViewModel in a `@State` property, which SwiftUI preserves across re-renders.

### The Splash Screen

The splash screen plays the "Mecher erwächt…" animation for exactly 2.5 seconds:
1. A Ken Burns pan animation (slow horizontal movement) plays over the `scene_village_aerial` image. The starting segment and direction are chosen randomly from three horizontal positions.
2. Concurrently, the `.task` modifier on `ContentView` initialises the database manager, creates the repository, and calls `seedIfNeeded()` — seeding runs in parallel with the animation.
3. After seeding completes, `MainViewModel` is created. Its `init()` immediately spawns a `Task` for `loadUnits()` — deferred to the next event loop tick so the main thread isn't blocked.
4. After 2.5 seconds, the splash screen fades out and the home screen appears.

On first install, if seeding takes longer than 2.5 seconds (unusual but possible on older devices), the splash transitions to a simple spinner ("Almost ready…") and waits. In practice, seeding 7,662 sentences takes well under 2.5 seconds.

---

## 12. The Review System

### The 3-Bucket Queue

When the user taps the Review card, `ContentRepository.buildReviewQueue(limit: 10)` is called. It collects every word the user has ever encountered (mastery > 0, across all lessons) and sorts them into three buckets:

**Bucket A — 60% of the session (weakest words):**  
Words with the lowest mastery scores. Sorted by mastery ascending, then by lesson number ascending (so older-lesson words with the same mastery are prioritised — early vocabulary shouldn't silently decay as new lessons push attention forward).

**Bucket B — 20% of the session (consolidating words):**  
Words in the medium mastery band (roughly 10–19), skipping what Bucket A already took.

**Bucket C — 20% of the session (random, including fully mastered):**  
A random sample from all encountered words, including fully mastered ones. This prevents the "I learned it, so I'll never see it again" problem — even mastered words need occasional reinforcement to stay retained.

The final queue of 10 items is shuffled before presentation so the ordering within each bucket isn't predictable. A Review Intro screen displays the 10 words (sorted by mastery, weakest first) before exercises begin.

### Review Exercise Types

Review sessions skip flashcards and reading exercises (the user has already encountered all these words). The selection leans toward more demanding types:

| Mastery range | Review exercise types |
|---|---|
| < 6 | Multiple Choice |
| 6–11 | Multiple Choice or Jumbled English (50/50) |
| 12–19 | Cloze or Jumbled Luxembourgish (50/50) |
| 20 | Cloze |
| Any (mastery ≥ 4) | Listening Comprehension (22% chance override) |
| Any (mastery ≥ 8) | Audio Dictation (15% chance override) |

---

## 13. Key Design Decisions and Why

### SwiftData over Core Data

Apple's older database framework (Core Data) required substantial boilerplate: separate model definitions, fetch request syntax, and complex migration scripts for schema changes. SwiftData (introduced iOS 17) eliminates most of this. `@Model` classes are the schema definition; SwiftData infers everything else. It also integrates cleanly with Swift's modern concurrency system (`async/await` and actors).

### Single Seed File

Alternatives considered: a remote CMS (content management system) or a cloud database. Both would require network calls for content, server infrastructure, authentication, and error handling for offline users. The seed file is simpler: bundle the JSON, load it on first install, update by shipping a new binary. LuxLingo works 100% offline, which is a strong user-experience guarantee for learners on planes, in rural areas, or with limited data.

### No User Accounts

All progress is stored locally in SwiftData. There are no accounts, no server-side user records, no login. This makes privacy the default: no personal data leaves the device, there's no GDPR concern, and the app works immediately without sign-up friction. The tradeoff is that progress cannot be synced across devices.

### MVVM with `@Observable`

The `@Observable` macro (a Swift 5.9+ feature) makes ViewModel state observation very precise: SwiftUI only re-renders the parts of the view that depend on properties that actually changed. Earlier patterns required manual `@Published` annotations on every property that should trigger updates. With `@Observable`, the whole class participates, but SwiftUI is smart enough to only re-draw what changed — giving both development simplicity and runtime efficiency.

### LOD.lu Audio for Non-Verbs, TTS for Verbs

When a speaker button is tapped for a verb, the LOD.lu audio file speaks the full dictionary entry title (e.g. "Hëllefsverb hunn, Participe passé gehat") — a format designed for dictionary reading, not language learning. This confused learners who expected to hear just the word. The fix: detect verb POS tags (`VRB`, `VRB+MOD`, `VRBPART`) from `SensesEntity.tags` and route all verbs to Sproochmaschinn TTS, which speaks only the word itself.

### Class-Body Defaults for Schema Evolution

When a new field is added to a SwiftData entity (a new "column" in the "spreadsheet"), SwiftData needs to know what value existing rows should get. By declaring the default value in the Swift class body (`var hasStarted: Bool = false`), SwiftData performs what's called a "lightweight migration" automatically — no migration script, no version matching, no risk of breaking existing user installs. This is the pattern used throughout the codebase for all fields added after the initial release.

### `clozeIndex` Rather Than the Surface Form

The sentence table stores the *position* of the target word (`clozeIndex = 1`) rather than the word itself (`nRuleForm = "ass"`). Storing the index keeps the data normalised: the actual word can always be extracted dynamically from `textLu.split(separator: " ")[clozeIndex]`. Storing the word form would create redundancy (the same text in two places) and a risk of the stored form and the sentence text diverging if a sentence is edited. The `nRuleForm` field is the one exception — it stores the n-rule variant of a word precisely because that variant must be looked up without re-running the Eifeler Regel logic at runtime.

---

## Appendix: File Map

| File | Purpose |
|---|---|
| `LuxLingoApp.swift` | App entry point; registers all 7 SwiftData entities with the model container |
| `ContentView.swift` | Root view: NavigationStack, splash screen, ExerciseScreenHost, AppRoute enum |
| `Database/Entities.swift` | All 7 `@Model` classes (the database schema) |
| `Database/DatabaseManager.swift` | Low-level SwiftData access methods (DAOs) |
| `Data/ContentRepository.swift` | All content logic: seeding, sentence selection, mastery recording, review queue |
| `Data/UserPreferences.swift` | XP, streak, and last-lesson-date stored in `@AppStorage` |
| `ViewModels/MainViewModel.swift` | Home screen state; bulk-fetch `loadUnits()` |
| `ViewModels/ExerciseViewModel.swift` | All exercise logic: type selection, answer checking, mastery updates |
| `Services/TTSService.swift` | Sproochmaschinn.lu TTS + LOD.lu audio playback |
| `Services/PronunciationService.swift` | Recording, LuxASR submission, polling, scoring |
| `Services/WordLookupService.swift` | LOD.lu dictionary lookup for the tap-a-word feature |
| `Services/AudioFeedbackService.swift` | Correct/wrong tones and haptics |
| `Models/Enums.swift` | `ExerciseTypeNew`, `AnswerFeedback`, `ExerciseResult` enums |
| `Models/Models.swift` | UI-layer structs: `CourseUnit`, `Lesson`, `VocabWord`, `MatchingItemModel` |
| `Models/SeedModels.swift` | Codable structs for parsing `initial_seed.json` |
| `Utils/EifelerRegel.swift` | Utility for the Luxembourgish n-rule (Eifeler Regel) logic |
| `Resources/initial_seed.json` | All lesson content: 468 words, 494 senses, 7,662 sentences, 70 core lessons |
