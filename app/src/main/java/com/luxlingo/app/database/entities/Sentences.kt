package com.luxlingo.app.database.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "sentences")
data class Sentences(
    @PrimaryKey val sentence_id: String,
    val text_lu: String,
    val text_en: String,
    val sense_ids: String,
    val cloze_index: Int,
    val lex_coverage: Double,
    val syn_density: Double,
    val is_handcrafted: Boolean
)
