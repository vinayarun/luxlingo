package com.luxlingo.app.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.luxlingo.app.database.entities.UserProgress

@Dao
interface UserProgressDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(progress: UserProgress)

    @Query("SELECT mastery FROM user_progress WHERE sense_id = :senseId LIMIT 1")
    suspend fun getMastery(senseId: String): Int?

    @Query("UPDATE user_progress SET mastery = :mastery WHERE sense_id = :senseId")
    suspend fun updateMastery(senseId: String, mastery: Int)
    
    @Query("SELECT * FROM user_progress WHERE sense_id = :senseId")
    suspend fun getUserProgress(senseId: String): UserProgress?

    @Query("UPDATE user_progress SET mastery = 0, exposure = 0, cloze_exposure = 0")
    suspend fun clearMastery()
}
