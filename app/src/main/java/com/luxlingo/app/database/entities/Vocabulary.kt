package com.luxlingo.app.database.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "vocabulary")
data class Vocabulary(
    @PrimaryKey val surface_id: String,
    val lemma_id: String,
    val word_text: String,
    val components: String? = null,
    val phonetic: String? = null,
    val audio_ref: String? = null
)
