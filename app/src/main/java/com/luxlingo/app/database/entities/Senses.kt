package com.luxlingo.app.database.entities

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "senses",
    foreignKeys = [
        ForeignKey(
            entity = Vocabulary::class,
            parentColumns = ["surface_id"],
            childColumns = ["surface_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index(value = ["surface_id"])]
)
data class Senses(
    @PrimaryKey val sense_id: String,
    val surface_id: String,
    val translations: String,
    val alt_en: String? = null,
    val tags: String,
    val is_golden_key: Boolean,
    val is_picturable: Boolean,
    val false_friend: String? = null
)
