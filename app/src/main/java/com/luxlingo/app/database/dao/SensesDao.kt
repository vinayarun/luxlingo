package com.luxlingo.app.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.luxlingo.app.database.entities.Senses

@Dao
interface SensesDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(sense: Senses)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(senses: List<Senses>)

    @Query("SELECT * FROM senses WHERE sense_id = :senseId")
    suspend fun getSense(senseId: String): Senses?

    // Required for the Seeder and Distractor logic
    @Query("SELECT * FROM senses")
    suspend fun getAllSensesOnce(): List<Senses>
}