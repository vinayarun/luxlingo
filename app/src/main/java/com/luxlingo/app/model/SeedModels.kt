package com.luxlingo.app.model

import com.google.gson.annotations.SerializedName

data class InitialSeedData(
    val vocabulary: List<SeedVocab>,
    val senses: List<SeedSense>,
    val sentences: List<SeedSentence>,
    val curriculum: List<SeedLesson>
)

data class SeedVocab(
    @SerializedName("surface_id") val surfaceId: String,
    @SerializedName("lemma_id") val lemmaId: String,
    @SerializedName("word_lu") val wordLu: String,
    @SerializedName("audio_ref") val audioRef: String
)

data class SeedSense(
    @SerializedName("sense_id") val senseId: String,
    @SerializedName("surface_id") val surfaceId: String,
    @SerializedName("primary_en") val primaryEn: String,
    val pos: String,
    @SerializedName("is_golden_key") val isGoldenKey: Boolean = false,
    @SerializedName("is_picturable") val isPicturable: Boolean = false
)

data class SeedSentence(
    @SerializedName("sentence_id") val sentenceId: String,
    @SerializedName("text_lu") val textLu: String,
    @SerializedName("text_en") val textEn: String,
    @SerializedName("sense_ids") val senseIds: List<String>,
    @SerializedName("cloze_index") val clozeIndex: Int
)

data class SeedLesson(
    @SerializedName("lesson_id") val lessonId: String,
    @SerializedName("title_en") val titleEn: String,
    @SerializedName("core_senses") val coreSenses: List<String>,
    @SerializedName("secondary_senses") val secondarySenses: List<String> = emptyList()
)