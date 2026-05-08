package com.luxlingo.app.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.luxlingo.app.database.entities.Curriculum

@Dao
interface CurriculumDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(curriculum: Curriculum)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(curriculum: List<Curriculum>)

    @Query("SELECT * FROM curriculum WHERE lesson_id = :lessonId")
    suspend fun getCurriculum(lessonId: String): Curriculum?

    @Query("SELECT * FROM curriculum")
    suspend fun getAllCurriculum(): List<Curriculum>
}
