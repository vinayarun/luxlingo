package com.luxlingo.app.database.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "curriculum")
data class Curriculum(
    @PrimaryKey val lesson_id: String,
    val title_en: String,
    val core_senses: String,
    val secondary_senses: String? = null,
    val prereqs: String? = null,
    val theme_tag: String? = null
)
