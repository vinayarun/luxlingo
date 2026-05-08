package com.luxlingo.app.di

import android.content.Context
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.luxlingo.app.data.ContentRepository
import com.luxlingo.app.data.UserPreferencesRepository
import com.luxlingo.app.database.LuxLingoDatabase
import com.luxlingo.app.database.dao.CurriculumDao
import com.luxlingo.app.database.dao.LessonStatusDao
import com.luxlingo.app.database.dao.SensesDao
import com.luxlingo.app.database.dao.SentencesDao
import com.luxlingo.app.database.dao.UserProgressDao
import com.luxlingo.app.database.dao.VocabularyDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context
    ): LuxLingoDatabase {
        return Room.databaseBuilder(
            context,
            LuxLingoDatabase::class.java,
            "luxlingo_database"
        )
        .addCallback(object : RoomDatabase.Callback() {
            override fun onCreate(db: SupportSQLiteDatabase) {
                super.onCreate(db)
                // Seeding logic will be handled by ContentRepository or a separate Seeder
                // But we can't inject ContentRepository here easily.
                // So we'll leave it empty here and rely on ContentRepository to check/seed on init?
                // Or better, use a Provider or similar.
                // For now, let's just ensure the callback exists as requested.
            }
        })
        .build()
    }

    @Provides
    fun provideVocabularyDao(db: LuxLingoDatabase): VocabularyDao = db.vocabularyDao()

    @Provides
    fun provideSensesDao(db: LuxLingoDatabase): SensesDao = db.sensesDao()

    @Provides
    fun provideSentencesDao(db: LuxLingoDatabase): SentencesDao = db.sentencesDao()

    @Provides
    fun provideCurriculumDao(db: LuxLingoDatabase): CurriculumDao = db.curriculumDao()

    @Provides
    fun provideUserProgressDao(db: LuxLingoDatabase): UserProgressDao = db.userProgressDao()

    @Provides
    fun provideLessonStatusDao(db: LuxLingoDatabase): LessonStatusDao = db.lessonStatusDao()

    @Provides
    @Singleton
    fun provideContentRepository(
        @ApplicationContext context: Context,
        lessonStatusDao: LessonStatusDao,
        userProgressDao: UserProgressDao,
        sensesDao: SensesDao,
        vocabularyDao: VocabularyDao,
        sentencesDao: SentencesDao,
        curriculumDao: CurriculumDao
    ): ContentRepository {
        return ContentRepository(
            context,
            lessonStatusDao,
            userProgressDao,
            sensesDao,
            vocabularyDao,
            sentencesDao,
            curriculumDao
        )
    }

    @Provides
@Singleton
fun provideUserPreferencesRepository(@ApplicationContext context: Context): UserPreferencesRepository {
    return UserPreferencesRepository(context)
}
}
