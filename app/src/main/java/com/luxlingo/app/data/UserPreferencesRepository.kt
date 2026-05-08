package com.luxlingo.app.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_preferences")

class UserPreferencesRepository(private val context: Context) {
    private val XP_KEY = intPreferencesKey("xp")
    private val STREAK_KEY = intPreferencesKey("streak")
    private val LAST_LESSON_DATE_KEY = longPreferencesKey("last_lesson_date")

    val xp: Flow<Int> = context.dataStore.data
        .map { preferences ->
            preferences[XP_KEY] ?: 0
        }

    val streak: Flow<Int> = context.dataStore.data
        .map { preferences ->
            preferences[STREAK_KEY] ?: 0
        }

    suspend fun addXp(amount: Int) {
        context.dataStore.edit { preferences ->
            val currentXp = preferences[XP_KEY] ?: 0
            preferences[XP_KEY] = currentXp + amount
        }
    }
    
    // Simple streak logic: if last lesson was yesterday, increment. If today, do nothing. Else reset to 1.
    suspend fun updateStreak() {
        val today = System.currentTimeMillis() / (1000 * 60 * 60 * 24) // Days since epoch
        
        context.dataStore.edit { preferences ->
            val lastDate = preferences[LAST_LESSON_DATE_KEY] ?: 0
            val currentStreak = preferences[STREAK_KEY] ?: 0
            
            if (lastDate == today - 1) {
                preferences[STREAK_KEY] = currentStreak + 1
            } else if (lastDate < today - 1) {
                preferences[STREAK_KEY] = 1
            } else if (currentStreak == 0) {
                 preferences[STREAK_KEY] = 1
            }
            
            preferences[LAST_LESSON_DATE_KEY] = today
        }
    }
}
