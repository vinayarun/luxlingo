package com.luxlingo.app.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.luxlingo.app.database.entities.Vocabulary

@Dao
interface VocabularyDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(vocabulary: Vocabulary) // Needed for the seeder loop

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(vocabulary: List<Vocabulary>)

    @Query("SELECT * FROM vocabulary WHERE surface_id = :surfaceId")
    suspend fun getVocabulary(surfaceId: String): Vocabulary?

    // Add this for the Matching Pairs logic in ContentRepository
    @Query("SELECT * FROM vocabulary WHERE surface_id = :id")
    suspend fun getVocabularyById(id: String): Vocabulary?
}