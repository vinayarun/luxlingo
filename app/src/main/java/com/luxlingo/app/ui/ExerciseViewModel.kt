package com.luxlingo.app.ui

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.luxlingo.app.data.ContentRepository
import com.luxlingo.app.data.ExerciseType
import com.luxlingo.app.data.AnswerFeedback
import com.luxlingo.app.data.ExerciseResult
import com.luxlingo.app.model.MatchingItem
import com.luxlingo.app.database.entities.Sentences
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ExerciseUiState(
    val lessonTitle: String = "",
    val currentSentence: Sentences? = null,
    val targetWord: String = "",
    val targetTranslation: String = "",
    val promptText: String = "",
    val sentenceParts: List<String> = emptyList(),
    val sentenceWithBlank: String = "",
    val multipleChoiceOptions: List<String> = emptyList(),
    val currentExerciseType: ExerciseType = ExerciseType.READING,
    val userInput: String = "",
    val feedback: AnswerFeedback = AnswerFeedback.NONE,
    val progress: Float = 0f,
    val totalSentences: Int = 0,   // 0 = not yet computed
    val currentSentenceIndex: Int = 0,
    val isLessonFinished: Boolean = false,
    val masteredSenses: List<String> = emptyList(),
    val shuffledTokens: List<String> = emptyList(),
    val matchingPairs: List<MatchingItem> = emptyList(),
    val isLoading: Boolean = false,
    val recentSentenceIds: List<String> = emptyList(),
    val failureCount: Int = 0,
    val consecutiveSenseCount: Int = 0,
    val lastSenseId: String = "",
    val exampleSentenceLu: String = "",
    val exampleSentenceEn: String = "",
    val phase: String = "Introduction",
    val sessionXP: Int = 0,
    val currentMastery: Int = 0,
    val maxMastery: Int = 0
)

@HiltViewModel
class ExerciseViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val contentRepository: ContentRepository
) : ViewModel() {
    private val lessonId: String = checkNotNull(savedStateHandle["lessonId"])
    private val _uiState = MutableStateFlow(ExerciseUiState())
    val uiState: StateFlow<ExerciseUiState> = _uiState.asStateFlow()

    init {
        loadNextExercise()
    }

    fun loadNextExercise() {
        _uiState.update { it.copy(userInput = "", feedback = AnswerFeedback.NONE, isLoading = true, failureCount = 0) }
        viewModelScope.launch {
            val coreSenses = contentRepository.getLessonCoreSenses(lessonId)
            if (coreSenses.isEmpty()) {
                finishLesson()
                return@launch
            }

            // 1. Check Phase: Introduction vs Challenge
            // Introduction Phase: Any core sense has mastery < 1
            val unintroducedSenses = coreSenses.filter { sense ->
                contentRepository.getSenseMastery(sense.sense_id) < 1
            }
            val isIntroPhase = unintroducedSenses.isNotEmpty()

            // 2. Sense Selection
            val lastSenseId = _uiState.value.lastSenseId
            val consecutiveCount = _uiState.value.consecutiveSenseCount
            
            val targetSense = when {
                isIntroPhase -> unintroducedSenses.first() // Force introduction of new words
                consecutiveCount >= 3 -> {
                    // Force pivot to core sense with lowest mastery
                    coreSenses.minByOrNull { contentRepository.getSenseMastery(it.sense_id) } ?: coreSenses.random()
                }
                else -> coreSenses.random()
            }

            // 3. Fetch Sentence specifically for the target sense
            val recentIds = _uiState.value.recentSentenceIds
            val sentence = contentRepository.getSentenceForLesson(lessonId, recentIds, targetSense.sense_id)
            
            if (sentence != null) {
                val senseId = targetSense.sense_id
                val mastery = contentRepository.getSenseMastery(senseId)
                val senseData = contentRepository.getSense(senseId)
                val translation = senseData?.translations ?: ""
                
                // Get canonical word text from Vocabulary
                val vocab = contentRepository.getVocabularyById(targetSense.surface_id)
                val targetWord = vocab?.word_text ?: ""

                // 4. Determine Exercise Type
                // Thresholds tuned so each phase lasts ~2-3 exercises before advancing.
                val type = when {
                    mastery < 1  -> ExerciseType.FLASHCARD
                    mastery < 6  -> ExerciseType.READING          // ~3 readings
                    mastery < 12 -> ExerciseType.MULTIPLE_CHOICE  // ~2 MCQ
                    mastery < 18 -> ExerciseType.JUMBLED_EN       // ~1-2 jumbled
                    mastery < 24 -> ExerciseType.JUMBLED_LU       // ~1-2 jumbled
                    else         -> ExerciseType.CLOZE
                }
                
                // 5. Jumbled Complexity Constraints
                val tokens = when (type) {
                    ExerciseType.JUMBLED_LU -> {
                        val baseTokens = cleanAndShuffleTokens(sentence.text_lu)
                        if (baseTokens.size < 5) {
                            val distractors = coreSenses.filter { it.sense_id != senseId }
                                .shuffled()
                                .take(2)
                                .map { it.translations }
                            (baseTokens + distractors).shuffled()
                        } else baseTokens
                    }
                    ExerciseType.JUMBLED_EN -> {
                        val baseTokens = cleanAndShuffleTokens(sentence.text_en)
                        if (baseTokens.size < 5) {
                            val distractors = coreSenses.filter { it.sense_id != senseId }
                                .shuffled()
                                .take(2)
                                .map { it.translations }
                            (baseTokens + distractors).shuffled()
                        } else baseTokens
                    }
                    else -> emptyList()
                }

                val prompt = when (type) {
                    ExerciseType.JUMBLED_EN -> sentence.text_lu
                    else -> sentence.text_en
                }
                
                // Update History Buffer
                val newRecentIds = (recentIds + sentence.sentence_id).takeLast(8)
                val currentState = _uiState.value
                val nextIndex = currentState.currentSentenceIndex + 1

                // Mastery Progress calculation: cap each sense at 20 points for progress
                val currentM = coreSenses.sumOf { contentRepository.getSenseMastery(it.sense_id).coerceAtMost(20) }
                val maxM = coreSenses.size * 20
                val progressVal = (currentM.toFloat() / maxM.toFloat()).coerceIn(0f, 1f)

                _uiState.update {
                    it.copy(
                        currentSentence = sentence,
                        promptText = prompt,
                        targetWord = targetWord,
                        targetTranslation = translation,
                        sentenceParts = splitSentence(sentence.text_lu, sentence.cloze_index),
                        currentExerciseType = type,
                        sentenceWithBlank = if (type == ExerciseType.MULTIPLE_CHOICE) {
                            val words = sentence.text_lu.split(" ")
                            val targetInSentence = words.getOrNull(sentence.cloze_index) ?: ""
                            sentence.text_lu.replace(targetInSentence, "______", ignoreCase = true)
                        } else "",
                        multipleChoiceOptions = if (type == ExerciseType.MULTIPLE_CHOICE) {
                            val words = sentence.text_lu.split(" ")
                            val targetInSentence = words.getOrNull(sentence.cloze_index) ?: ""
                            (contentRepository.getRandomDistractors(targetInSentence, 3) + targetInSentence).shuffled()
                        } else emptyList(),
                        shuffledTokens = tokens,
                        currentSentenceIndex = nextIndex,
                        progress = progressVal,
                        currentMastery = currentM,
                        maxMastery = maxM,
                        isLoading = false,
                        recentSentenceIds = newRecentIds,
                        lastSenseId = senseId,
                        consecutiveSenseCount = if (senseId == lastSenseId) consecutiveCount + 1 else 1,
                        exampleSentenceLu = sentence.text_lu,
                        exampleSentenceEn = sentence.text_en,
                        phase = if (isIntroPhase) "Introduction" else "Challenge"
                    )
                }
            } else {
                // If no sentence found for target sense, check if lesson is mastered
                if (contentRepository.areAllCoreSensesMastered(lessonId)) {
                    finishLesson()
                } else {
                    // Try again with a different sense
                    loadNextExercise()
                }
            }
        }
    }

    fun onInputChanged(newInput: String) {
        _uiState.update { it.copy(userInput = newInput, feedback = AnswerFeedback.NONE) }
    }

    fun onOptionSelected(option: String) {
        onInputChanged(option)
        checkAnswer()
    }

    fun onReadingContinue() {
        _uiState.update { it.copy(feedback = AnswerFeedback.CORRECT, sessionXP = it.sessionXP + 5) }
        viewModelScope.launch {
            recordResult(ExerciseResult.READING)
            delay(500)
            loadNextExercise()
        }
    }

    fun onFlashcardContinue() {
        _uiState.update { it.copy(feedback = AnswerFeedback.CORRECT, sessionXP = it.sessionXP + 5) }
        viewModelScope.launch {
            recordResult(ExerciseResult.READING)
            delay(500)
            loadNextExercise()
        }
    }

    fun onSkipExercise() {
        viewModelScope.launch {
            loadNextExercise()
        }
    }

    fun checkAnswer() {
        val currentState = _uiState.value
        val type = currentState.currentExerciseType

        if (type == ExerciseType.MATCHING) {
            _uiState.update { it.copy(feedback = AnswerFeedback.CORRECT) }
            viewModelScope.launch {
                recordResult(ExerciseResult.MATCHING)
                delay(1500)
                loadNextExercise()
            }
            return
        }
        
        val sentence = currentState.currentSentence ?: return
        val userInput = normalizeText(currentState.userInput)
        
        val comparisonTargetRaw = when (type) {
            ExerciseType.JUMBLED_LU -> sentence.text_lu
            ExerciseType.JUMBLED_EN -> sentence.text_en
            ExerciseType.CLOZE, ExerciseType.MULTIPLE_CHOICE -> {
                val words = sentence.text_lu.split(" ")
                val safeIndex = sentence.cloze_index.coerceIn(0, words.size - 1)
                words.getOrElse(safeIndex) { "" }
            }
            else -> currentState.targetWord
        }
        
        val comparisonTarget = normalizeText(comparisonTargetRaw)

        val (feedback, result) = when (type) {
            ExerciseType.JUMBLED_LU, ExerciseType.JUMBLED_EN -> {
                if (userInput == comparisonTarget) AnswerFeedback.CORRECT to ExerciseResult.CLOZE
                else AnswerFeedback.WRONG to ExerciseResult.ERROR
            }
            ExerciseType.MULTIPLE_CHOICE -> {
                if (userInput == comparisonTarget) AnswerFeedback.CORRECT to ExerciseResult.MULTIPLE_CHOICE
                else AnswerFeedback.WRONG to ExerciseResult.ERROR
            }
            else -> {
                val distance = levenshtein(userInput, comparisonTarget)
                val isNRule = distance == 1 && (userInput.trimEnd('n') == comparisonTarget.trimEnd('n'))
                when {
                    distance == 0 -> AnswerFeedback.CORRECT to ExerciseResult.CLOZE
                    isNRule -> AnswerFeedback.N_RULE to ExerciseResult.CLOZE
                    distance == 1 -> AnswerFeedback.TYPO to ExerciseResult.CLOZE
                    else -> AnswerFeedback.WRONG to ExerciseResult.ERROR
                }
            }
        }

        _uiState.update { 
            it.copy(
                feedback = feedback,
                failureCount = if (feedback == AnswerFeedback.WRONG) it.failureCount + 1 else 0
            ) 
        }

        viewModelScope.launch {
            val resultType = if (result == ExerciseResult.ERROR) ExerciseResult.ERROR
            else when (type) {
                ExerciseType.MULTIPLE_CHOICE -> ExerciseResult.MULTIPLE_CHOICE
                ExerciseType.JUMBLED_LU -> ExerciseResult.JUMBLED_LU
                ExerciseType.JUMBLED_EN -> ExerciseResult.JUMBLED_EN
                else -> result
            }

            recordResult(resultType)

            // Award XP: full amount for correct/near-correct, 1 effort point for wrong
            // so the counter always ticks and the user knows the app registered their attempt.
            val xpGained = if (feedback == AnswerFeedback.WRONG) {
                1
            } else {
                when (type) {
                    ExerciseType.MULTIPLE_CHOICE                     -> 10
                    ExerciseType.JUMBLED_LU, ExerciseType.JUMBLED_EN -> 15
                    ExerciseType.CLOZE -> if (feedback == AnswerFeedback.CORRECT) 25 else 10
                    else -> 5
                }
            }
            _uiState.update { it.copy(sessionXP = it.sessionXP + xpGained) }

            if (feedback != AnswerFeedback.WRONG) {
                delay(1500)
                if (contentRepository.areAllCoreSensesMastered(lessonId)) finishLesson()
                else loadNextExercise()
            }
        }
    }

    private suspend fun finishLesson() {
        contentRepository.completeLesson(lessonId)
        val coreSenses = contentRepository.getLessonCoreSenses(lessonId)
        val masteredLabels = coreSenses.map { it.translations }
        _uiState.update { it.copy(isLessonFinished = true, masteredSenses = masteredLabels, isLoading = false) }
    }

    private suspend fun recordResult(result: ExerciseResult) {
        val currentState = _uiState.value
        
        fun getWeight(res: ExerciseResult): Int {
            return when (res) {
                ExerciseResult.READING -> 1
                ExerciseResult.MATCHING -> 3
                ExerciseResult.MULTIPLE_CHOICE -> 4
                ExerciseResult.JUMBLED_LU, ExerciseResult.JUMBLED_EN -> 8
                ExerciseResult.CLOZE -> 10
                ExerciseResult.ERROR -> -2
                else -> 0
            }
        }

        if (currentState.currentExerciseType == ExerciseType.MATCHING) {
            currentState.matchingPairs.forEach { item ->
                contentRepository.recordExerciseResult(item.id, getWeight(ExerciseResult.MATCHING))
            }
            return
        }

        currentState.currentSentence?.let { sentence ->
            val isCloze = result == ExerciseResult.CLOZE
            if (result == ExerciseResult.ERROR) {
                val senseId = contentRepository.getSenseIdForCloze(sentence)
                if (senseId != null) contentRepository.recordExerciseResult(senseId, getWeight(result), isCloze = false)
            } else {
                val lessonCoreSenses = contentRepository.getLessonCoreSenses(lessonId).map { it.sense_id }.toSet()
                val sentenceSenses = sentence.sense_ids.split(",").toSet()
                val targetSenseId = contentRepository.getSenseIdForCloze(sentence)
                
                if (targetSenseId != null) {
                    contentRepository.recordExerciseResult(targetSenseId, getWeight(result), isCloze = isCloze)
                }

                val secondarySenses = sentenceSenses.intersect(lessonCoreSenses) - (targetSenseId ?: "")
                secondarySenses.forEach { senseId ->
                    val mastery = contentRepository.getSenseMastery(senseId)
                    // Mastery Weighting Correction: +2 for secondary senses in Challenge (MCQ/Cloze)
                    val secondaryWeight = if (currentState.currentExerciseType == ExerciseType.MULTIPLE_CHOICE || currentState.currentExerciseType == ExerciseType.CLOZE) 2 else 1
                    
                    if (mastery == 0) {
                        repeat(3) { contentRepository.recordExerciseResult(senseId, secondaryWeight, isCloze = false) }
                    } else {
                        contentRepository.recordExerciseResult(senseId, secondaryWeight, isCloze = false)
                    }
                }

                val fillerSenses = sentenceSenses.subtract(lessonCoreSenses)
                fillerSenses.forEach { senseId ->
                    contentRepository.recordExerciseResult(senseId, getWeight(ExerciseResult.READING), isCloze = false)
                }
            }
        }
    }

    private fun splitSentence(sentence: String, index: Int): List<String> {
        if (sentence.isBlank()) return listOf("", "")
        val words = sentence.split(" ")
        val safeIndex = index.coerceIn(0, words.size - 1)
        val before = words.subList(0, safeIndex).joinToString(" ")
        val after = words.subList(safeIndex + 1, words.size).joinToString(" ")
        return listOf(before, after)
    }

    private fun cleanAndShuffleTokens(text: String): List<String> {
        return text.split(" ")
            .map { it.trim { c -> ".,?!:;\"()".contains(c) } }
            .filter { it.isNotEmpty() }
            .shuffled()
    }

    private fun normalizeText(text: String): String {
        return text.trim()
            .lowercase()
            .replace(Regex("[.,?!:;\"()]"), "") // Robust punctuation stripping
    }

    private fun levenshtein(lhs: CharSequence, rhs: CharSequence): Int {
        val len0 = lhs.length + 1
        val len1 = rhs.length + 1
        var cost = IntArray(len0) { it }
        var newCost = IntArray(len0)
        for (i in 1 until len1) {
            newCost[0] = i
            for (j in 1 until len0) {
                val match = if (lhs[j - 1] == rhs[i - 1]) 0 else 1
                newCost[j] = minOf(newCost[j - 1] + 1, cost[j] + 1, cost[j - 1] + match)
            }
            val swap = cost; cost = newCost; newCost = swap
        }
        return cost[len0 - 1]
    }
}