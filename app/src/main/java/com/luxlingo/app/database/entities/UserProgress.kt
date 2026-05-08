package com.luxlingo.app.database.entities

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index

@Entity(
    tableName = "user_progress",
    primaryKeys = ["user_id", "sense_id", "surface_id"],
    foreignKeys = [
        ForeignKey(
            entity = Senses::class,
            parentColumns = ["sense_id"],
            childColumns = ["sense_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index(value = ["sense_id"])]
)
data class UserProgress(
    val user_id: String,
    val sense_id: String,
    val surface_id: String,
    val exposure: Int,
    val mastery: Int,
    val cloze_exposure: Int = 0, // New field to track successful Cloze completions
    val last_error: String? = null,
    val fsrs_data: String? = null
)
