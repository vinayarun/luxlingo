package com.luxlingo.app.database.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "lesson_status")
data class LessonStatus(
    @PrimaryKey val lesson_id: String,
    val title_en: String = "",
    val is_completed: Boolean = false,
    val mastery: Int = 0,
    val completion_percentage: Double = 0.0
)