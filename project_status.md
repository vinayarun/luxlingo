# LuxLingo Project Status

## 🎯 Objective
Build a light, offline-first Luxembourgish language learning app for Android (Kotlin + Jetpack Compose) for English speakers.

## 🏗️ Architecture
- **Pattern**: MVVM (Model-View-ViewModel)
- **UI**: Jetpack Compose (Single Activity)
- **Data Source**: Local JSON (`assets/units.json`)
- **Persistence**: DataStore Preferences (XP & Streak)
- **Build System**: Gradle (Kotlin DSL)
- **Containerization**: Docker (for reproducible builds)

## 🚀 Current Features
1.  **Home Screen**:
    - Lists Units and Lessons.
    - Displays User XP and Streak (persisted).
2.  **Lesson Player**:
    - Supports multiple exercise types:
        - Multiple Choice (MCQ)
        - Match Pairs
        - Reorder Sentence
        - Fill-in-Blank
    - Progress bar and feedback system.
3.  **Gamification**:
    - Earn XP for correct answers.
    - Daily Streak tracking.
4.  **Offline Capability**:
    - All content is bundled with the app.
    - No internet connection required.

## 🛠️ Technical Implementation
### Data Layer
- `ContentRepository`: Parses `units.json`.
- `UserPreferencesRepository`: Manages `DataStore` for saving XP and Streak.

### UI Layer
- `MainActivity`: Navigation host.
- `LessonViewModel`: Manages lesson state, scoring, and interacts with repositories.
- `ExerciseComponents`: Reusable Composable widgets for exercises.

### Docker Build
- `Dockerfile`: Configured with Android SDK (API 34), Build Tools, and Gradle.
- `docker-compose.yml`: Mounts the project directory and caches Gradle/SDK to speed up builds.
- **Build Command**: `sudo docker compose run --rm --entrypoint "" android-builder bash -c "gradle assembleDebug"`

## 🔜 Next Steps
1.  **Speech Integration**: Implement `SpeechService` using Android's `TextToSpeech`.
2.  **Content Expansion**: Add more units to `units.json`.
3.  **UI Polish**: Add animations and better assets (replace placeholder icons).
