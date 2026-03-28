package com.luxlingo.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.*
import com.luxlingo.app.data.ContentRepository
import com.luxlingo.app.model.CourseUnit
import com.luxlingo.app.model.Lesson
import com.luxlingo.app.model.UnitMetadata
import com.luxlingo.app.model.Word
import com.luxlingo.app.database.entities.LessonStatus
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    application: Application,
    private val repository: ContentRepository
) : AndroidViewModel(application) {
    // private val repository = ContentRepository(application) // Removed manual instantiation
    
    val units: StateFlow<List<CourseUnit>> = repository.allLessonsFlow
        .map { statuses ->
            val mappedUnits = repository.getUnits().map { unit ->
                // val words = repository.getWordsFromUnit(unit.id) // This relied on unit_X.json files
                // For now, we can't easily get word count without querying DB or parsing core_senses
                // Let's just use a placeholder or remove the word count from title if needed.
                // Or better, we can query the core senses count.
                
                val status = statuses.find { it.lesson_id == unit.id }
                
                val lesson = Lesson(
                    id = unit.id,
                    title = unit.title, // Use the unit title as lesson title for now
                    isCompleted = status?.is_completed ?: false,
                    objective = "Master the core vocabulary",
                    exercises = emptyList()
                )
                unit.copy(lessons = listOf(lesson))
            }
            android.util.Log.d("LuxLingo", "MainViewModel: Mapped to ${mappedUnits.size} units")
            mappedUnits
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    
    fun getWords(unitId: String): List<Word> {
        return repository.getWordsFromUnit(unitId)
    }
    
    fun getLesson(unitId: String, lessonId: String): Lesson? {
        return units.value.find { it.id == unitId }?.lessons?.find { it.id == lessonId }
    }
}
