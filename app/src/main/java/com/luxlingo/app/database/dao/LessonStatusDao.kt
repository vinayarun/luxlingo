package com.luxlingo.app.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.luxlingo.app.database.entities.LessonStatus
import kotlinx.coroutines.flow.Flow

@Dao
interface LessonStatusDao {
    @Query("SELECT * FROM lesson_status WHERE lesson_id = :lessonId")
    suspend fun getLessonStatus(lessonId: String): LessonStatus?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(lessonStatus: LessonStatus)

    // FIX: Using Flow ensures the Homepage updates instantly when mastery changes
    @Query("SELECT * FROM lesson_status")
    fun getAllStatusesFlow(): Flow<List<LessonStatus>>

    @Insert(onConflict = OnConflictStrategy.IGNORE) // FIX: IGNORE preserves saved progress
    suspend fun insertAll(lessons: List<LessonStatus>)
}