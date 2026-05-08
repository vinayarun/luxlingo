package com.luxlingo.app.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.luxlingo.app.database.entities.Sentences

@Dao
interface SentencesDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(sentence: Sentences)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(sentences: List<Sentences>)

    @Query("SELECT * FROM sentences WHERE sentence_id = :sentenceId")
    suspend fun getSentence(sentenceId: String): Sentences?

    @Query("SELECT * FROM sentences WHERE sense_ids LIKE '%' || :senseId || '%'")
    suspend fun getSentencesContainingSense(senseId: String): List<Sentences>
}
