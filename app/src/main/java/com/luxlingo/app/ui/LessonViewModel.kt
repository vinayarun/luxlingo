package com.luxlingo.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.luxlingo.app.data.UserPreferencesRepository
import com.luxlingo.app.model.Exercise
import com.luxlingo.app.model.ExerciseType
import com.luxlingo.app.model.Word
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.random.Random

class LessonViewModel(
    private val words: List<Word>,
    private val unitId: String,
    private val userPreferencesRepository: UserPreferencesRepository
) : ViewModel() {

    private val _currentIndex = MutableStateFlow(0)
    val currentIndex = _currentIndex.asStateFlow()

    private val _xp = MutableStateFlow(0)
    val xp = _xp.asStateFlow()
    
    private val _isLessonComplete = MutableStateFlow(false)
    val isLessonComplete = _isLessonComplete.asStateFlow()

    // UI State for feedback
    private val _feedbackState = MutableStateFlow<FeedbackState>(FeedbackState.None)
    val feedbackState = _feedbackState.asStateFlow()

    // Generate exercises dynamically from words
    private val generatedExercises: List<Exercise> = generateExercises(words)

    val currentExercise: Exercise?
        get() = if (_currentIndex.value < generatedExercises.size) generatedExercises[_currentIndex.value] else null

    val totalExercises = generatedExercises.size
    
    // Helper for UI to observe
    fun getProgressFlow() = _currentIndex

    private fun generateExercises(words: List<Word>): List<Exercise> {
        val exercises = mutableListOf<Exercise>()
        var exerciseId = 0

        // Sort words by unit_rank to maintain progression (beginner to advanced)
        val sortedWords = words.sortedBy { it.unitRank }

        sortedWords.forEach { word ->
            // Progressive learning: Start simple, then increase difficulty
            // 1. First: Simple MCQ to introduce the word
            exercises.add(generateMCQ(word, words, exerciseId++))
            
            // 2. Second: Show word in context (both languages) - Introduction exercise
            exercises.add(generateIntroduction(word, exerciseId++))
            
            // 3. Third: Fill-in-blank (only if sentence is simple enough)
            if (isSimpleSentence(word.exampleLb)) {
                exercises.add(generateFillInBlank(word, words, exerciseId++))
            }
            
            // 4. Fourth: Translation (only for simpler sentences in early units)
            if (word.unitRank <= 15 && isSimpleSentence(word.exampleLb)) {
                exercises.add(generateTranslate(word, exerciseId++))
            }
        }

        return exercises // Don't shuffle - maintain progression
    }
    
    private fun isSimpleSentence(sentence: String): Boolean {
        // Consider a sentence simple if it has 6 or fewer words
        val wordCount = sentence.trim().split(Regex("\\s+")).size
        return wordCount <= 6
    }
    
    private fun generateIntroduction(word: Word, id: Int): Exercise {
        // Introduction exercise: Show word with translation and example
        // This is a "learning" exercise, not a test - user just clicks continue
        return Exercise(
            id = "${word.id}_intro_$id",
            type = ExerciseType.MATCH, // Reuse MATCH type for introduction display
            prompt = "${word.word} = ${word.translation}",
            correctAnswer = "learned",
            options = listOf(
                word.word,
                word.translation,
                word.exampleLb,
                word.exampleEn
            )
        )
    }

    private fun generateMCQ(word: Word, allWords: List<Word>, id: Int): Exercise {
        // Get distractors from the same unit (ensure we have at least 3, or use all available)
        val availableWords = allWords.filter { it.id != word.id }
        val numDistractors = minOf(3, availableWords.size)
        val distractors = availableWords
            .shuffled()
            .take(numDistractors)
            .map { it.translation.trim() }

        // Normalize the correct answer (handle "of / by" -> "of/by")
        val correctAnswer = normalizeAnswer(word.translation)
        val normalizedDistractors = distractors.map { normalizeAnswer(it) }
        
        // Ensure correct answer is in options
        val allOptions = (listOf(correctAnswer) + normalizedDistractors).distinct()
        val options = if (allOptions.size < 4) {
            // If we don't have enough options, pad with generic ones
            val genericOptions = listOf("yes", "no", "maybe", "always", "never")
            (allOptions + genericOptions).distinct().take(4).shuffled()
        } else {
            allOptions.shuffled()
        }
        
        // Double-check correct answer is in options
        val finalOptions = if (!options.contains(correctAnswer)) {
            (listOf(correctAnswer) + options.take(3)).shuffled()
        } else {
            options
        }

        return Exercise(
            id = "${word.id}_mcq_$id",
            type = ExerciseType.MCQ,
            prompt = "What does \"${word.word}\" mean?",
            correctAnswer = correctAnswer,
            options = finalOptions
        )
    }
    
    private fun normalizeAnswer(answer: String): String {
        // Normalize: trim, lowercase, handle "/" variations
        return answer.trim().lowercase()
            .replace(Regex("\\s*/\\s*"), "/") // Normalize "of / by" to "of/by"
            .replace(Regex("\\s+"), " ") // Normalize multiple spaces
    }

    private fun generateFillInBlank(word: Word, allWords: List<Word>, id: Int): Exercise {
        // Use the full sentence and identify the index of the target word
        val sentence = word.exampleLb
        val words = sentence.split(" ")
        // Find index of the word (checking if the token contains the target word to handle punctuation)
        val index = words.indexOfFirst { it.contains(word.word, ignoreCase = true) }
        val clozeIndex = if (index != -1) index else null

        // Get 3 random distractors
        val distractors = allWords
            .filter { it.id != word.id }
            .shuffled()
            .take(3)
            .map { it.word }

        val options = (listOf(word.word) + distractors).shuffled()

        return Exercise(
            id = "${word.id}_fill_$id",
            type = ExerciseType.FILL,
            prompt = sentence,
            correctAnswer = word.word,
            options = options,
            clozeIndex = clozeIndex
        )
    }

    private fun generateTranslate(word: Word, id: Int): Exercise {
        return Exercise(
            id = "${word.id}_translate_$id",
            type = ExerciseType.TRANSLATE,
            prompt = word.exampleEn,
            correctAnswer = word.exampleLb,
            options = null
        )
    }

    fun checkAnswer(answer: String) {
        val exercise = currentExercise ?: return
        
        // Introduction exercises (learning cards) are always correct
        val isIntroduction = exercise.id.contains("_intro_") || exercise.prompt.contains("=")
        
        // Normalize both answers for comparison
        val normalizedUserAnswer = normalizeAnswer(answer)
        val normalizedCorrectAnswer = normalizeAnswer(exercise.correctAnswer)
        
        // Simple validation logic
        val isCorrect = when {
            isIntroduction -> true // Introduction exercises are always correct
            exercise.type == ExerciseType.MATCH -> true // Logic handled in UI component for now
            exercise.type == ExerciseType.TRANSLATE -> {
                // For translate, check if answer matches the Luxembourgish example
                // Allow partial matches for longer sentences
                normalizedUserAnswer == normalizedCorrectAnswer ||
                normalizedCorrectAnswer.contains(normalizedUserAnswer, ignoreCase = true) ||
                normalizedUserAnswer.contains(normalizedCorrectAnswer, ignoreCase = true)
            }
            else -> normalizedUserAnswer == normalizedCorrectAnswer
        }

        if (isCorrect) {
            // Don't give XP for introduction exercises (they're just learning cards)
            if (!isIntroduction) {
                _xp.value += 10
            }
            _feedbackState.value = FeedbackState.Correct
        } else {
            _feedbackState.value = FeedbackState.Incorrect(exercise.correctAnswer)
        }
    }

    fun continueToNext() {
        _feedbackState.value = FeedbackState.None
        if (_currentIndex.value < totalExercises - 1) {
            _currentIndex.value += 1
        } else {
            finishLesson()
        }
    }

    private fun finishLesson() {
        viewModelScope.launch {
            userPreferencesRepository.addXp(_xp.value)
            userPreferencesRepository.updateStreak()
            _isLessonComplete.value = true
        }
    }
}

sealed class FeedbackState {
    object None : FeedbackState()
    object Correct : FeedbackState()
    data class Incorrect(val correctAnswer: String) : FeedbackState()
}

class LessonViewModelFactory(
    private val words: List<Word>,
    private val unitId: String,
    private val userPreferencesRepository: UserPreferencesRepository
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(LessonViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return LessonViewModel(words, unitId, userPreferencesRepository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
