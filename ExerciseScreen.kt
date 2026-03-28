package com.example.luxlingo.ui.exercise

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController

@Composable
fun ExerciseScreen(
    navController: NavController,
    viewModel: ExerciseViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    if (uiState.isLessonFinished) {
        LessonSummaryScreen(
            masteredSenses = uiState.masteredSenses,
            onBackToMenu = { navController.popBackStack() }
        )
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(uiState.lessonTitle) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        if (uiState.currentSentence == null && !uiState.isLessonFinished) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else if (uiState.currentSentence != null) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .imePadding()
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())
                ) {
                    ExerciseHeader(
                        progress = uiState.progress,
                        progressText = "Sentence ${uiState.currentSentenceIndex} of ${uiState.totalSentences}"
                    )
                    Spacer(Modifier.height(64.dp))

                    // English translation as a hint
                    Text(
                        text = uiState.currentSentence.text_en,
                        style = MaterialTheme.typography.h6,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f),
                        textAlign = TextAlign.Center
                    )
                    Spacer(Modifier.height(16.dp))

                    // Cloze sentence with input field
                    ClozeSentenceInput(
                        parts = uiState.sentenceParts,
                        userInput = uiState.userInput,
                        feedback = uiState.feedback,
                        onInputChanged = viewModel::onInputChanged,
                        onDone = viewModel::checkAnswer
                    )

                    if (uiState.feedback != AnswerFeedback.NONE) {
                        Spacer(Modifier.height(16.dp))
                        Text(
                            text = when (uiState.feedback) {
                                AnswerFeedback.N_RULE -> "Right word, but check the N-Rule!"
                                AnswerFeedback.TYPO -> "Close! Check your spelling."
                                AnswerFeedback.WRONG -> "Incorrect"
                                AnswerFeedback.CORRECT -> "Correct!"
                                else -> ""
                            },
                            style = MaterialTheme.typography.body1,
                            color = when (uiState.feedback) {
                                AnswerFeedback.CORRECT -> Color(0xFF4CAF50)
                                AnswerFeedback.WRONG -> Color(0xFFF44336)
                                else -> Color(0xFFFFC107)
                            }
                        )
                    }
                }

                Button(
                    onClick = viewModel::checkAnswer,
                    enabled = uiState.userInput.isNotBlank() && uiState.feedback == AnswerFeedback.NONE,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                ) {
                    Text("Check")
                }
            }
        }
    }
}

@Composable
fun LessonSummaryScreen(
    masteredSenses: List<String>,
    onBackToMenu: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("Lesson Complete!", style = MaterialTheme.typography.h4)
        Spacer(Modifier.height(24.dp))
        Text("You mastered:", style = MaterialTheme.typography.h6)
        Spacer(Modifier.height(8.dp))
        masteredSenses.forEach { word ->
            Text(word, style = MaterialTheme.typography.body1)
        }
        Spacer(Modifier.height(32.dp))
        Button(onClick = onBackToMenu, modifier = Modifier.fillMaxWidth()) {
            Text("Back to Menu")
        }
    }
}

@Composable
private fun ExerciseHeader(progress: Float, progressText: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Text(progressText, style = MaterialTheme.typography.caption)
        Spacer(Modifier.height(4.dp))
        LinearProgressIndicator(
            progress = progress,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun ClozeSentenceInput(
    parts: List<String>,
    userInput: String,
    feedback: AnswerFeedback,
    onInputChanged: (String) -> Unit,
    onDone: () -> Unit
) {
    val feedbackColor = when (feedback) {
        AnswerFeedback.CORRECT -> Color(0xFF4CAF50) // Green
        AnswerFeedback.TYPO -> Color(0xFFFFC107) // Amber
        AnswerFeedback.N_RULE -> Color(0xFFFFC107) // Amber
        AnswerFeedback.WRONG -> Color(0xFFF44336) // Red
        AnswerFeedback.NONE -> MaterialTheme.colors.primary
    }

    // Using FlowRow to allow sentence to wrap naturally
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.wrapContentHeight()
    ) {
        if (parts.getOrNull(0)?.isNotBlank() == true) {
            Text(text = "${parts[0]} ", style = MaterialTheme.typography.h5)
        }

        BasicTextField(
            value = userInput,
            onValueChange = onInputChanged,
            textStyle = MaterialTheme.typography.h5.copy(
                textAlign = TextAlign.Center,
                color = MaterialTheme.colors.onSurface
            ),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onDone() }),
            singleLine = true,
            modifier = Modifier.width(IntrinsicSize.Min)
        ) { innerTextField ->
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                innerTextField()
                Spacer(Modifier.height(2.dp))
                Box(
                    modifier = Modifier
                        .widthIn(min = 40.dp)
                        .fillMaxWidth()
                        .height(2.dp)
                        .background(feedbackColor)
                )
            }
        }

        if (parts.getOrNull(1)?.isNotBlank() == true) {
            Text(text = " ${parts[1]}", style = MaterialTheme.typography.h5)
        }
    }
}