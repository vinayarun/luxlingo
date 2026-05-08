# LuxLingo - Luxembourgish Learning App

## Architecture Overview

This Android application is built using **Kotlin** and **Jetpack Compose**, following the **MVVM (Model-View-ViewModel)** architecture pattern.

### Key Components:

1.  **Data Layer**:
    *   `ContentRepository`: Responsible for loading lesson content from local JSON files (`assets/units.json`). This ensures the app works offline as requested.
    *   **JSON Data Model**: The content is structured hierarchically: `Unit` -> `Lesson` -> `Exercise`. This allows for easy expansion.

2.  **Domain/Model**:
    *   Data classes (`CourseUnit`, `Lesson`, `Exercise`) represent the core business logic.
    *   `ExerciseType` enum handles the variety of exercise widgets (MCQ, Match, Reorder, etc.).

3.  **UI Layer (Jetpack Compose)**:
    *   `MainActivity`: Hosts the `NavHost` for navigation between screens.
    *   `HomeScreen`: Displays the list of units and lessons.
    *   `LessonScreen`: The core interactive screen. It observes `LessonViewModel` to display the current exercise and feedback.
    *   `ResultScreen`: Shows the summary after a lesson.
    *   `ExerciseComponents`: Reusable Composable functions for each exercise type (`MCQExercise`, `ReorderExercise`, etc.).

4.  **State Management**:
    *   `LessonViewModel`: Manages the state of the active lesson (current index, score, feedback state). It uses `StateFlow` to expose data to the UI, ensuring reactive updates.
    *   `MainViewModel`: Holds the global data (list of units) to avoid reloading from disk on every navigation.

### Design Decisions:
*   **Jetpack Compose**: Chosen for its declarative nature, making it easier to build dynamic UIs like the exercise player.
*   **Single Activity**: The app uses a single Activity with Navigation Compose, which is the modern standard for Android apps.
*   **Offline First**: Content is bundled in `assets`, satisfying the requirement for offline access.

## How to Extend (Adding Unit 2)

1.  Open `app/src/main/assets/units.json`.
2.  Add a new Unit object to the array:
    ```json
    {
      "id": "unit_2",
      "title": "Food & Drink",
      "lessons": [ ... ]
    }
    ```
3.  The app will automatically parse and display the new unit on the Home Screen upon restart. No code changes are needed for new content unless you add a new *type* of exercise.

## Future Improvements
*   **Speech Integration**: The `SpeechService` interface is ready. Implement `AndroidSpeechService` using Android's `TextToSpeech` and `SpeechRecognizer` APIs.
*   **Persistence**: Currently, progress (XP) is passed in navigation. To persist it, integrate `Room` database or `DataStore` to save user progress across sessions.
