package com.luxlingo.app.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.luxlingo.app.database.dao.CurriculumDao
import com.luxlingo.app.database.dao.LessonStatusDao
import com.luxlingo.app.database.dao.SensesDao
import com.luxlingo.app.database.dao.SentencesDao
import com.luxlingo.app.database.dao.UserProgressDao
import com.luxlingo.app.database.dao.VocabularyDao
import com.luxlingo.app.database.entities.Curriculum
import com.luxlingo.app.database.entities.LessonStatus
import com.luxlingo.app.database.entities.Senses
import com.luxlingo.app.database.entities.Sentences
import com.luxlingo.app.database.entities.UserProgress
import com.luxlingo.app.database.entities.Vocabulary
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@Database(
    entities = [
        Vocabulary::class,
        Senses::class,
        Sentences::class,
        Curriculum::class,
        UserProgress::class,
        LessonStatus::class
    ],
    version = 1,
    exportSchema = false
)
abstract class LuxLingoDatabase : RoomDatabase() {
    abstract fun vocabularyDao(): VocabularyDao
    abstract fun sensesDao(): SensesDao
    abstract fun sentencesDao(): SentencesDao
    abstract fun curriculumDao(): CurriculumDao
    abstract fun userProgressDao(): UserProgressDao
    abstract fun lessonStatusDao(): LessonStatusDao

    companion object {
        @Volatile
        private var INSTANCE: LuxLingoDatabase? = null

        fun getDatabase(context: Context, scope: CoroutineScope): LuxLingoDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    LuxLingoDatabase::class.java,
                    "luxlingo_database"
                )
                // FIX: Use onCreate, not onOpen, to prevent resetting progress
                .addCallback(DatabaseCallback(context, scope))
                .build()
                INSTANCE = instance
                instance
            }
        }
    }

    private class DatabaseCallback(
        private val context: Context,
        private val scope: CoroutineScope
    ) : RoomDatabase.Callback() {
        override fun onCreate(db: SupportSQLiteDatabase) {
            super.onCreate(db)
            // This is where you call your JSON seeding logic
            // e.g., scope.launch { populateDatabase(database) }
        }
    }
}