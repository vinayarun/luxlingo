The finalized specification for the **LuxLingo Pedagogical Engine
(v2.0)**. This 5-table setup is optimized for high-speed lookups in a
mobile environment while maintaining the complex linguistic
relationships needed for Luxembourgish.

### 🏛️ LuxLingo 5-Table Master Schema

#### 1. Table: **vocabulary** (The Surface/Asset Layer)

Tracks the literal word as it appears on the screen and its associated
media.

  ---------------- ----------------- --------------------------------------------------------------------------- -----
  **surface_id**   **String (PK)**   Unique ID for the specific spelling (e.g., **w_001**).                      NO
  **lemma_id**     **String**        Links variants to a root (e.g., **ass** and **sinn** link to **l_sinn**).   NO
  **word_lu**      **String**        The literal Luxembourgish string.                                           NO
  **components**   **Array\[ID\]**   For compound words (e.g., **Kaffis** + **Maschinn**).                       YES
  **phonetic**     **String**        IPA pronunciation script.                                                   YES
  **audio_ref**    **String**        Local path or URL to the **.mp3** file.                                     YES
  ---------------- ----------------- --------------------------------------------------------------------------- -----

#### 2. Table: **senses** (The Semantic/Meaning Layer)

The \"Brain.\" Handles polysemy, translations, and pedagogical flags.

  ------------------- --------------------- ------------------------------------------------------ -----
  **sense_id**        **String (PK)**       Unique ID for the meaning (e.g., **ginn_v_become**).   NO
  **surface_id**      **String (FK)**       Links to the visual form in **vocabulary**.            NO
  **primary_en**      **String**            The main translation shown on intro cards.             NO
  **alt_en**          **Array\[String\]**   Alternative accepted English translations.             YES
  **pos**             **Enum**              Part of Speech (Noun, Verb, Adj, Filler, etc.).        NO
  **is_golden_key**   **Boolean**           True if this is a high-frequency \"glue\" word.        NO
  **is_picturable**   **Boolean**           True if word can be represented by an icon/image.      NO
  **false_friend**    **String**            Note for EN/DE/FR interference (e.g., \"Brav\").       YES
  **tags**            **JSON**              Domain (Food), Register (Formal), Cognate flags.       YES
  ------------------- --------------------- ------------------------------------------------------ -----

#### 3. Table: **sentences** (The Context Layer)

A library of handcrafted pedagogical examples used to build exercises.

  -------------------- ----------------- ------------------------------------------------------- ----
  **sentence_id**      **String (PK)**   Unique ID for the sentence.                             NO
  **text_lu**          **String**        The full sentence in Luxembourgish.                     NO
  **text_en**          **String**        The full sentence in English.                           NO
  **sense_ids**        **Array\[FK\]**   Every **sense_id** used in this sentence.               NO
  **cloze_index**      **Integer**       Which word index to hide for fill-in-the-blank.         NO
  **lex_coverage**     **Float**         \% of words in sentence already \"unlocked\" by user.   NO
  **syn_density**      **Integer**       Complexity score (1 = Simple, 5 = Advanced).            NO
  **is_handcrafted**   **Boolean**       True if verified for beginner pedagogy.                 NO
  -------------------- ----------------- ------------------------------------------------------- ----

#### 4. Table: **curriculum** (The Path Layer)

The director that sequences the user journey.

  ----------------- ----------------- ------------------------------------------------- -----
  **lesson_id**     **String (PK)**   Unique ID for the lesson (e.g., **L_01**).        NO
  **title_en**      **String**        Human-readable title (e.g., \"At the Bakery\").   NO
  **core_senses**   **Array\[FK\]**   The new meanings being introduced in this unit.   NO
  **prereqs**       **Array\[FK\]**   **lesson_id**s that must be mastered first.       YES
  **theme_tag**     **String**        Grouping tag (e.g., \"Food\", \"Basics\").        YES
  ----------------- ----------------- ------------------------------------------------- -----

#### 5. Table: **user_progress** (The Learning Layer)

The dynamic table tracking Mastery, Exposure, and Spaced Repetition.

  ---------------- ----------------- ---------------------------------------------------- -----
  **user_id**      **String (PK)**   Unique identifier for the user.                      NO
  **sense_id**     **String (PK)**   The meaning being tracked.                           NO
  **surface_id**   **String (PK)**   The specific spelling being tracked.                 NO
  **exposure**     **Integer**       Total times seen (Reading = **+1**).                 NO
  **mastery**      **Integer**       Proficiency score (MC = **+5**, Cloze = **+10**).    NO
  **last_error**   **Enum**          **TYPO**, **WRONG_SENSE**, **GENDER**, **N_RULE**.   YES
  **fsrs_data**    **JSON**          FSRS stability, difficulty, and last review date.    NO
  ---------------- ----------------- ---------------------------------------------------- -----

### 🛠️ Strategic Summary

-   **The \"Glue\" Logic:** By using the **is_golden_key** boolean in
    the **senses** table, the app knows to prioritize these words in the
    early curriculum and weight them differently in complexity
    calculations.
-   **Error Intelligence:** The **last_error** field in
    **user_progress** allows the app to show \"Smart Tips.\" If a user
    fails an exercise with a **TYPO** error, the app can offer a
    spelling hint instead of a full vocabulary re-teach.
-   **Zipf\'s Law Readiness:** You can now query for the top 1000
    **senses** and instantly find every **vocabulary** string and
    **sentence** associated with them.
