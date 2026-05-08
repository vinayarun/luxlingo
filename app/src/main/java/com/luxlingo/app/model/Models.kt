package com.luxlingo.app.model

import com.google.gson.annotations.SerializedName

data class Word(
    val rank: Int,
    val word: String,
    val translation: String,
    @SerializedName("example_lb") val exampleLb: String,
    @SerializedName("example_en") val exampleEn: String,
    val id: String,
    @SerializedName("unit_rank") val unitRank: Int
)

data class UnitMetadata(
    @SerializedName("unit_number") val unitNumber: Int? = null,
    val title: String? = null,
    val description: String? = null
)

// Support both old format (array of words) and new format (with metadata)
data class UnitData(
    @SerializedName("unit_metadata") val unitMetadata: UnitMetadata? = null,
    val words: List<Word>? = null
)

data class CourseUnit(
    val id: String,
    val title: String,
    val lessons: List<Lesson>
)

data class Lesson(
    val id: String,
    val title: String,
    val objective: String,
    val exercises: List<Exercise>,
    val isCompleted: Boolean = false
)

data class Exercise(
    val id: String,
    val type: ExerciseType,
    val prompt: String,
    @SerializedName("correct_answer") val correctAnswer: String,
    val options: List<String>? = null,
    val hint: String? = null,
    @SerializedName("audio_text") val audioText: String? = null,
    // Add this line to bridge the Gap between the JSON and the UI logic
    @SerializedName("cloze_index") val clozeIndex: Int? = null,
    @SerializedName("target_translation") val targetTranslation: String? = null
)

data class MatchingItem(
    val id: String,
    val nativeText: String,
    val translatedText: String
)

enum class ExerciseType {
    @SerializedName("mcq") MCQ,
    @SerializedName("match") MATCH,
    @SerializedName("reorder") REORDER,
    @SerializedName("fill") FILL,
    @SerializedName("translate") TRANSLATE,
    @SerializedName("listen") LISTEN,
    @SerializedName("speak") SPEAK,
    @SerializedName("flashcard") FLASHCARD
}
