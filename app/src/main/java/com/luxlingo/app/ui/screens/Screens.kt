package com.luxlingo.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.luxlingo.app.model.CourseUnit
import com.luxlingo.app.model.ExerciseType
import com.luxlingo.app.ui.FeedbackState
import com.luxlingo.app.ui.LessonViewModel
import com.luxlingo.app.ui.components.FillInBlankExercise
import com.luxlingo.app.ui.components.MatchExercise
import com.luxlingo.app.ui.components.MCQExercise
import com.luxlingo.app.ui.components.ReorderExercise
import com.luxlingo.app.ui.components.TranslateExercise

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    units: List<CourseUnit>,
    xp: Int,
    streak: Int,
    onLessonSelected: (String, String) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("LuxLingo")
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("🔥 $streak", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(16.dp))
                            Text("💎 $xp", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(8.dp))
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .padding(16.dp)
        ) {
            items(units) { unit ->
                UnitCard(unit, onLessonSelected)
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@Composable
fun UnitCard(unit: CourseUnit, onLessonSelected: (String, String) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = unit.title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
            
            unit.lessons.forEachIndexed { index, lesson ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp)
                        .clickable { onLessonSelected(unit.id, lesson.id) },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "${index + 1}",
                            color = Color.White,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Spacer(modifier = Modifier.width(16.dp))
                    Column {
                        Text(text = lesson.title, style = MaterialTheme.typography.titleMedium)
                        Text(text = lesson.objective, style = MaterialTheme.typography.bodySmall)
                    }
                }
                if (index < unit.lessons.size - 1) {
                    Divider(modifier = Modifier.padding(start = 56.dp))
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LessonScreen(
    viewModel: LessonViewModel,
    onLessonComplete: (Int) -> Unit,
    onBack: () -> Unit
) {
    val currentIndex by viewModel.currentIndex.collectAsState()
    val currentExercise = viewModel.currentExercise
    val progress = (currentIndex.toFloat() / viewModel.totalExercises.toFloat()).coerceIn(0f, 1f)
    
    val feedbackState by viewModel.feedbackState.collectAsState()
    val isComplete by viewModel.isLessonComplete.collectAsState()
    val xp by viewModel.xp.collectAsState()

    LaunchedEffect(isComplete) {
        if (isComplete) {
            onLessonComplete(xp)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    LinearProgressIndicator(
                        progress = progress,
                        modifier = Modifier.fillMaxWidth().padding(end = 16.dp)
                    ) 
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        bottomBar = {
            // Feedback Bottom Sheet
            if (feedbackState !is FeedbackState.None) {
                FeedbackSheet(
                    state = feedbackState,
                    onContinue = { viewModel.continueToNext() }
                )
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            currentExercise?.let { exercise ->
                when (exercise.type) {
                    ExerciseType.MCQ -> MCQExercise(
                        exercise = exercise,
                        onAnswerSelected = { viewModel.checkAnswer(it) },
                        feedbackState = feedbackState
                    )
                    ExerciseType.MATCH -> MatchExercise(
                        exercise = exercise,
                        onAnswerSelected = { viewModel.checkAnswer(it) },
                        feedbackState = feedbackState
                    )
                    ExerciseType.REORDER -> ReorderExercise(
                        exercise = exercise,
                        onAnswerSelected = { viewModel.checkAnswer(it) },
                        feedbackState = feedbackState
                    )
                    ExerciseType.FILL -> FillInBlankExercise(
                        exercise = exercise,
                        onAnswerSelected = { viewModel.checkAnswer(it) },
                        feedbackState = feedbackState
                    )
                    ExerciseType.TRANSLATE -> TranslateExercise(
                        exercise = exercise,
                        onAnswerSelected = { viewModel.checkAnswer(it) },
                        feedbackState = feedbackState
                    )
                    else -> Text("Exercise type ${exercise.type} not implemented yet")
                }
            }
        }
    }
}

@Composable
fun FeedbackSheet(state: FeedbackState, onContinue: () -> Unit) {
    val backgroundColor = when (state) {
        is FeedbackState.Correct -> Color(0xFFD7FFB8) // Light Green
        is FeedbackState.Incorrect -> Color(0xFFFFD7D7) // Light Red
        else -> Color.Transparent
    }
    
    val textColor = when (state) {
        is FeedbackState.Correct -> Color(0xFF58A700)
        is FeedbackState.Incorrect -> Color(0xFFEA2B2B)
        else -> Color.Black
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(backgroundColor)
            .padding(24.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                if (state is FeedbackState.Correct) Icons.Default.Check else Icons.Default.Star, // Use Star for error for now or X
                contentDescription = null,
                tint = textColor,
                modifier = Modifier.size(32.dp)
            )
            Spacer(modifier = Modifier.width(16.dp))
            Text(
                text = if (state is FeedbackState.Correct) "Excellent!" else "Incorrect",
                style = MaterialTheme.typography.headlineSmall,
                color = textColor,
                fontWeight = FontWeight.Bold
            )
        }
        
        if (state is FeedbackState.Incorrect) {
            Text(
                text = "Correct answer: ${state.correctAnswer}",
                color = textColor,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
        
        Button(
            onClick = onContinue,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 24.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = textColor
            )
        ) {
            Text("CONTINUE", color = Color.White)
        }
    }
}

@Composable
fun ResultScreen(xp: Int, onHome: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Lesson Complete!",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(32.dp))
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
        ) {
            Column(
                modifier = Modifier.padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("Total XP Earned", style = MaterialTheme.typography.titleMedium)
                Text(
                    text = "+$xp",
                    style = MaterialTheme.typography.displayLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
        
        Spacer(modifier = Modifier.height(48.dp))
        
        Button(
            onClick = onHome,
            modifier = Modifier.fillMaxWidth().height(56.dp)
        ) {
            Text("CONTINUE", fontSize = 18.sp)
        }
    }
}
