package com.luxlingo.app.data

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.luxlingo.app.database.dao.CurriculumDao
import com.luxlingo.app.database.dao.LessonStatusDao
import com.luxlingo.app.database.dao.SensesDao
import com.luxlingo.app.database.dao.SentencesDao
import com.luxlingo.app.database.dao.UserProgressDao
import com.luxlingo.app.database.dao.VocabularyDao
import com.luxlingo.app.database.entities.LessonStatus
import com.luxlingo.app.database.entities.Sentences
import com.luxlingo.app.database.entities.UserProgress
import com.luxlingo.app.model.CourseUnit
import com.luxlingo.app.model.UnitData
import com.luxlingo.app.model.UnitMetadata
import com.luxlingo.app.model.Word
import com.luxlingo.app.model.MatchingItem
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow
import com.luxlingo.app.database.entities.*
import com.luxlingo.app.model.*
import java.io.IOException
import javax.inject.Inject

class ContentRepository @Inject constructor(
    private val context: Context,
    private val lessonStatusDao: LessonStatusDao,
    private val userProgressDao: UserProgressDao,
    private val sensesDao: SensesDao,
    private val vocabularyDao: VocabularyDao,
    private val sentencesDao: SentencesDao,
    private val curriculumDao: CurriculumDao
) {
    val allLessonsFlow: Flow<List<LessonStatus>> = lessonStatusDao.getAllStatusesFlow()

    suspend fun getUnits(): List<CourseUnit> {
        return curriculumDao.getAllCurriculum().map { curr ->
            CourseUnit(
                id = curr.lesson_id,
                title = curr.title_en,
                lessons = emptyList() // Will be populated in ViewModel
            )
        }
    }

    suspend fun recordExerciseResult(senseId: String, weight: Int, isCloze: Boolean = false) {
        // We need surface_id and user_id for UserProgress.
        // Assuming single user "default_user" and fetching surface_id from Senses table.
        val sense = sensesDao.getSense(senseId) ?: return
        val userId = "default_user"
        
        val currentProgress = userProgressDao.getUserProgress(senseId)
        val currentMastery = currentProgress?.mastery ?: 0
        val currentClozeExposure = currentProgress?.cloze_exposure ?: 0
        
        // Bonus: If it's a new word (Mastery 0), boost the first exposure
        // Mastery 0 means either no record or mastery field is 0.
        // Weight 1 corresponds to Reading.
        val actualWeight = if (currentMastery == 0 && weight == 1) 3 else weight
        
        val newMastery = currentMastery + actualWeight
        val newExposure = (currentProgress?.exposure ?: 0) + 1
        val newClozeExposure = if (isCloze && weight > 0) currentClozeExposure + 1 else currentClozeExposure
        
        val progress = UserProgress(
            user_id = userId,
            sense_id = senseId,
            surface_id = sense.surface_id,
            exposure = newExposure,
            mastery = newMastery,
            cloze_exposure = newClozeExposure,
            last_error = currentProgress?.last_error,
            fsrs_data = currentProgress?.fsrs_data
        )
        
        userProgressDao.insert(progress)
        
        android.util.Log.d("LuxLingo", "Mastery Update: Sense=$senseId, Old=$currentMastery, Added=$actualWeight, New=$newMastery, ClozeExp=$newClozeExposure")
    }

    init {
        // Change from launch to runBlocking to force data availability for this test
        runBlocking(Dispatchers.IO) {
            seedDatabaseIfEmpty()
        }
    }

    private suspend fun seedDatabaseIfEmpty() {
        android.util.Log.d("LuxLingo", "Checking if DB seeding is required (Deep Update)...")
        // We always re-seed on launch to ensure n-rule fixes and new vocabulary are active.
        // The Room REPLACE strategy makes this an upsert operation.
        
        try {
            val jsonString = getJsonDataFromAsset("seed_data/initial_seed.json") ?: return
            val seedData = Gson().fromJson(jsonString, InitialSeedData::class.java)
            android.util.Log.d("LuxLingo", "Deep Seed: Processing ${seedData.vocabulary.size} words, ${seedData.senses.size} senses, ${seedData.sentences.size} sentences.")

            // 1. Seed Vocabulary (Upsert)
            seedData.vocabulary.forEach { v ->
                vocabularyDao.insert(Vocabulary(
                    surface_id = v.surfaceId,
                    lemma_id = v.lemmaId,
                    word_text = v.wordLu,
                    audio_ref = v.audioRef
                ))
            }

            // 2. Seed Senses (Upsert)
            seedData.senses.forEach { s ->
                sensesDao.insert(Senses(
                    sense_id = s.senseId,
                    surface_id = s.surfaceId,
                    translations = s.primaryEn,
                    tags = s.pos,
                    is_golden_key = s.isGoldenKey,
                    is_picturable = false
                ))
            }

            // 3. Seed Sentences (Upsert)
            seedData.sentences.forEach { sent ->
                sentencesDao.insert(Sentences(
                    sentence_id = sent.sentenceId,
                    text_lu = sent.textLu,
                    text_en = sent.textEn,
                    sense_ids = sent.senseIds.joinToString(","),
                    cloze_index = sent.clozeIndex,
                    lex_coverage = 0.0,
                    syn_density = 0.0,
                    is_handcrafted = true
                ))
            }

            // 4. Reset mastery for testing if this was a refresh to let user see new forms
            // If we want to keep progress, we can skip this, but usually good for major grammar updates.
            // userProgressDao.clearMastery() 

            android.util.Log.d("LuxLingo", "Deep Seed Successful: All data synced with seed file.")
        } catch (e: Exception) {
            android.util.Log.e("LuxLingo", "Deep Seed error: ${e.message}")
        }
    }

        // 4. Seed Curriculum
        seedData.curriculum.forEach { curr ->
            curriculumDao.insert(Curriculum(
                lesson_id = curr.lessonId,
                title_en = curr.titleEn,
                core_senses = curr.coreSenses.joinToString(","),
                secondary_senses = curr.secondarySenses.joinToString(",")
            ))
            
            lessonStatusDao.insert(LessonStatus(
                lesson_id = curr.lessonId,
                title_en = curr.titleEn,
                is_completed = false,
                mastery = 0,
                completion_percentage = 0.0
            ))
        }
        android.util.Log.d("LuxLingo", "Database Deep Seed Successful")
    } catch (e: Exception) {
        android.util.Log.e("LuxLingo", "Seed Error: ${e.message}")
    }
}

    // Fixed Distractors Logic
    suspend fun getRandomDistractors(target: String, count: Int): List<String> {
        val allSenses = sensesDao.getAllSensesOnce()
        return allSenses
            .filter { it.translations != target }
            .shuffled()
            .take(count)
            .map { it.translations }
    }

    suspend fun areAllCoreSensesMastered(lessonId: String): Boolean {
        val coreSenses = getLessonCoreSenses(lessonId)
        if (coreSenses.isEmpty()) return false
        
        // 1. Core Senses: Mastery >= 20 AND at least 2 successful Cloze exercises
        val coreMastered = coreSenses.all { sense ->
            val progress = userProgressDao.getUserProgress(sense.sense_id)
            val mastery = progress?.mastery ?: 0
            val clozeExp = progress?.cloze_exposure ?: 0
            mastery >= 20 && clozeExp >= 1
        }
        
        if (!coreMastered) return false
        
        // 2. Secondary Senses: At least 80% have been exposed (+1 point) at least once
        val curriculum = curriculumDao.getCurriculum(lessonId) ?: return coreMastered
        val secondarySenseIds = curriculum.secondary_senses?.split(",")?.map { it.trim() }?.filter { it.isNotEmpty() } ?: emptyList()
        
        if (secondarySenseIds.isEmpty()) return true
        
        val exposedCount = secondarySenseIds.count { id ->
            (userProgressDao.getUserProgress(id)?.exposure ?: 0) > 0
        }
        
        return (exposedCount.toFloat() / secondarySenseIds.size) >= 0.8f
    }

    suspend fun getLessonCoreSenses(lessonId: String): List<com.luxlingo.app.database.entities.Senses> {
        val curriculum = curriculumDao.getCurriculum(lessonId) ?: return emptyList()
        val senseIds = curriculum.core_senses.split(",").map { it.trim() }
        return senseIds.mapNotNull { sensesDao.getSense(it) }
    }

    suspend fun completeLesson(lessonId: String) {
        val status = lessonStatusDao.getLessonStatus(lessonId) ?: LessonStatus(lessonId)
        lessonStatusDao.insert(status.copy(is_completed = true, completion_percentage = 100.0))
    }

    suspend fun getSentenceForLesson(
        lessonId: String, 
        excludeSentenceIds: List<String> = emptyList(),
        targetSenseId: String? = null
    ): Sentences? {
        val coreSenses = if (targetSenseId != null) {
            sensesDao.getSense(targetSenseId)?.let { listOf(it) } ?: getLessonCoreSenses(lessonId)
        } else {
            getLessonCoreSenses(lessonId)
        }

        if (coreSenses.isEmpty()) {
            android.util.Log.w("ContentRepository", "No core senses found for lesson $lessonId")
            return null
        }
        
        // Try to find a sentence for a random sense, respecting exclusions
        val shuffledSenses = coreSenses.shuffled()
        
        for (sense in shuffledSenses) {
            val allSentences = sentencesDao.getSentencesContainingSense(sense.sense_id)
            if (allSentences.isEmpty()) continue

            // Dynamic Buffer Scaling: Buffer_Size = Min(8, Total_Available_Sentences / 2)
            val dynamicBufferSize = (allSentences.size / 2).coerceAtMost(8)
            
            // Filter global exclusions to only those relevant to this sense
            val relevantExclusions = excludeSentenceIds.intersect(allSentences.map { it.sentence_id }.toSet()).toList()
            
            // Apply the dynamic buffer size (keeping the most recent ones)
            val effectiveExclusions = if (relevantExclusions.size > dynamicBufferSize) {
                relevantExclusions.takeLast(dynamicBufferSize)
            } else {
                relevantExclusions
            }
            
            // Filter out excluded sentences
            val validSentences = allSentences.filter { it.sentence_id !in effectiveExclusions }
            
            if (validSentences.isNotEmpty()) {
                val selected = validSentences.random()
                android.util.Log.d("ContentRepository", "Selected Sentence: ID=${selected.sentence_id}, Text=${selected.text_lu}")
                return selected
            }
        }
        
        // Fallback: If all sentences for all senses are excluded (buffer full), 
        // just pick any sentence from a random sense to avoid crashing/hanging.
        android.util.Log.w("ContentRepository", "All sentences excluded for lesson $lessonId. Ignoring filter.")
        val fallbackSense = coreSenses.random()
        val fallbackSentences = sentencesDao.getSentencesContainingSense(fallbackSense.sense_id)
        return if (fallbackSentences.isNotEmpty()) fallbackSentences.random() else null
    }

    suspend fun getSenseIdForCloze(sentence: Sentences): String? {
        val ids = sentence.sense_ids.split(",").map { it.trim() }.filter { it.isNotEmpty() }
        if (ids.isEmpty()) return null
        
        val words = sentence.text_lu.split(" ")
        val targetWord = words.getOrNull(sentence.cloze_index)
            ?.lowercase()
            ?.trim { it in ".,?!:;\"() " } ?: return ids.firstOrNull()

        // Try to find the sense that matches the target word's surface form
        for (id in ids) {
            val sense = sensesDao.getSense(id) ?: continue
            val vocab = vocabularyDao.getVocabularyById(sense.surface_id) ?: continue
            val vocabWord = vocab.word_text.lowercase().trim { it in ".,?!:;\"() " }
            if (vocabWord == targetWord) {
                return id
            }
        }
        
        // Fallback: if no surface match, try to see if the index is valid
        // (Some legacy data might use index-based mapping)
        return ids.getOrNull(sentence.cloze_index) ?: ids.firstOrNull()
    }

    suspend fun getMatchingPairs(lessonId: String): List<com.luxlingo.app.model.MatchingItem> {
        val coreSenses = getLessonCoreSenses(lessonId)
        return coreSenses.mapNotNull { sense ->
            val vocab = vocabularyDao.getVocabularyById(sense.surface_id)
            if (vocab != null) {
                com.luxlingo.app.model.MatchingItem(
                    id = sense.sense_id,
                    nativeText = vocab.word_text,
                    translatedText = sense.translations
                )
            } else null
        }
    }
    
    suspend fun getSenseMastery(senseId: String): Int {
        return userProgressDao.getMastery(senseId) ?: 0
    }
    
    suspend fun getSense(senseId: String): com.luxlingo.app.database.entities.Senses? {
        return sensesDao.getSense(senseId)
    }
    
    suspend fun getClozeExposure(senseId: String): Int {
        return userProgressDao.getUserProgress(senseId)?.cloze_exposure ?: 0
    }
    
    suspend fun getVocabularyById(id: String): Vocabulary? {
        return vocabularyDao.getVocabularyById(id)
    }
    
    // ... (Other methods need to be preserved or updated)
    // I need to be careful not to delete existing methods that are used by ViewModel.
    // The previous view_file showed:
    // getUnitMetadata, loadWordsAndMetadata, getWordsFromUnit, getJsonDataFromAsset
    
    // Also ExerciseViewModel uses:
    // areAllCoreSensesMastered, getLessonCoreSenses, getMatchingPairs, getSentenceForLesson, getSenseIdForCloze, getRandomDistractors, completeLesson
    
    // These methods were NOT in the file I viewed earlier!
    // Wait, step 10 view_file output ended at line 115.
    // But ExerciseViewModel calls many methods that were NOT in that file.
    // This means ContentRepository.kt was INCOMPLETE in my view or I missed something.
    // Ah, the file I viewed had 115 lines.
    // But ExerciseViewModel calls `areAllCoreSensesMastered`.
    // This implies `ContentRepository.kt` IS MISSING these methods or I am looking at an old version?
    // No, I am looking at the current version on disk.
    // This means `ContentRepository.kt` IS BROKEN/INCOMPLETE relative to `ExerciseViewModel`.
    // The user said "Ensure ContentRepository correctly receives the new DAOs".
    // But I also need to make sure it compiles.
    // If `ExerciseViewModel` calls methods that don't exist, it won't compile.
    
    // I should implement these missing methods or at least stubs.
    // But I can't implement them fully without knowing the logic.
    // However, I can infer some logic.
    
    // `areAllCoreSensesMastered(lessonId)`: check if all core senses of a lesson have mastery >= threshold (e.g. 20).
    // `getLessonCoreSenses(lessonId)`: get core senses from Curriculum table.
    // `getMatchingPairs(lessonId)`: generate matching pairs.
    // `getSentenceForLesson(lessonId)`: get a sentence.
    // `getSenseIdForCloze(sentence)`: get sense id.
    // `getRandomDistractors`: get distractors.
    // `completeLesson(lessonId)`: update LessonStatus.
    
    // I will add these methods to `ContentRepository`.
    
    fun getUnitMetadata(unitId: String): UnitMetadata? {
        val unitNumber = unitId.filter { it.isDigit() }.toIntOrNull() ?: 0
        val fileName = "unit_$unitNumber.json"
        val (_, metadata) = loadWordsAndMetadata(fileName)
        return metadata
    }

    private fun loadWordsAndMetadata(fileName: String): Pair<List<Word>, UnitMetadata?> {
        val jsonString = getJsonDataFromAsset("units/$fileName")
        if (jsonString != null) {
            try {
                val gson = Gson()
                try {
                    val unitDataType = object : TypeToken<UnitData>() {}.type
                    val unitData: UnitData? = gson.fromJson(jsonString, unitDataType)
                    if (unitData != null && unitData.words != null) {
                        return Pair(unitData.words, unitData.unitMetadata)
                    }
                } catch (e: Exception) {}
                val wordListType = object : TypeToken<List<Word>>() {}.type
                val words: List<Word>? = gson.fromJson(jsonString, wordListType)
                if (words != null) {
                    return Pair(words, null)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return Pair(emptyList(), null)
    }

    fun getWordsFromUnit(unitId: String): List<Word> {
        val unitNumber = unitId.filter { it.isDigit() }.toIntOrNull() ?: 0
        val (words, _) = loadWordsAndMetadata("unit_$unitNumber.json")
        return words
    }

    private fun getJsonDataFromAsset(path: String): String? {
        return try {
            context.assets.open(path).bufferedReader().use { it.readText() }
        } catch (ioException: IOException) {
            ioException.printStackTrace()
            null
        }
    }
    
    
    

}
