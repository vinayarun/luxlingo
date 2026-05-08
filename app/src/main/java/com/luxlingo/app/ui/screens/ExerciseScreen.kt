package com.luxlingo.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
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
import com.luxlingo.app.ui.ExerciseViewModel
import com.luxlingo.app.data.ExerciseType
import com.luxlingo.app.ui.components.FlashcardExercise
import com.luxlingo.app.ui.components.JumbledWordRow
import com.luxlingo.app.ui.components.LuxlingoButton
import com.luxlingo.app.ui.components.MatchingExercise
import com.luxlingo.app.data.AnswerFeedback
import com.luxlingo.app.database.entities.Sentences
import com.luxlingo.app.model.MatchingItem

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExerciseScreen(
    navController: NavController,
    viewModel: ExerciseViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val currentSentence = uiState.currentSentence
    val isMatching = uiState.currentExerciseType == ExerciseType.MATCHING

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
    ) { innerPadding ->
        if (uiState.isLoading || (currentSentence == null && !isMatching && !uiState.isLessonFinished)) {
            Box(modifier = Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else if (currentSentence != null || isMatching) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
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
                        progressText = if (isMatching) "Match the pairs"
                            else "Mastery ${uiState.currentMastery} / ${uiState.maxMastery}",
                        phase = uiState.phase,
                        sessionXP = uiState.sessionXP
                    )
                    Spacer(Modifier.height(64.dp))

                    if (isMatching) {
                        Text(
                            text = "Match the pairs",
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                            textAlign = TextAlign.Center
                        )
                    } else if (currentSentence != null) {
                        // 1. Show Prompt (English Hint or Source Text)
                        Text(
                            text = uiState.promptText.ifEmpty { currentSentence.text_en },
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                            textAlign = TextAlign.Center
                        )
                    }
                    Spacer(Modifier.height(16.dp))


                    // Dynamic Exercise Content
                    when (uiState.currentExerciseType) {
                        ExerciseType.FLASHCARD -> {
                            FlashcardExercise(
                                targetWord = uiState.targetWord,
                                translation = uiState.targetTranslation,
                                exampleSentenceLu = uiState.exampleSentenceLu,
                                exampleSentenceEn = uiState.exampleSentenceEn,
                                onContinue = { viewModel.onFlashcardContinue() }
                            )
                        }
                        ExerciseType.READING -> {
                            // Flashcard Mode: Show the full Luxembourgish sentence clearly
                            Text(
                                text = currentSentence?.text_lu ?: "",
                                style = MaterialTheme.typography.headlineMedium,
                                textAlign = TextAlign.Center,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                text = "(New word! Read this aloud)",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                        }
                        ExerciseType.JUMBLED_LU, ExerciseType.JUMBLED_EN -> {
                            val selectedTokens = uiState.userInput.split(" ").filter { it.isNotEmpty() }
                            JumbledWordRow(
                                availableTokens = uiState.shuffledTokens,
                                selectedTokens = selectedTokens,
                                onTokenSelected = { token: String ->
                                    val newTokens = selectedTokens + token
                                    viewModel.onInputChanged(newTokens.joinToString(" "))
                                },
                                onTokenRemoved = { token ->
                                    val newTokens = selectedTokens.toMutableList()
                                    newTokens.remove(token)
                                    viewModel.onInputChanged(newTokens.joinToString(" "))
                                }
                            )
                        }
                        ExerciseType.MULTIPLE_CHOICE -> {
                            // Display sentence with a blank and show choice buttons
                            Text(text = uiState.sentenceWithBlank, style = MaterialTheme.typography.headlineSmall)
                            Spacer(Modifier.height(32.dp))
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                uiState.multipleChoiceOptions.forEach { option ->
                                    Button(
                                        onClick = { viewModel.onOptionSelected(option) },
                                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                                        shape = MaterialTheme.shapes.medium
                                    ) {
                                        Text(text = option, style = MaterialTheme.typography.labelLarge)
                                    }
                                }
                            }
                        }
                        ExerciseType.MATCHING -> {
                            MatchingExercise(
                                pairs = uiState.matchingPairs,
                                onComplete = {
                                    viewModel.onInputChanged("DONE")
                                    viewModel.checkAnswer()
                                }
                            )
                        }
                        else -> { // CLOZE
                            ClozeSentenceInput(
                                parts = uiState.sentenceParts,
                                userInput = uiState.userInput,
                                feedback = uiState.feedback,
                                onInputChanged = viewModel::onInputChanged,
                                onDone = viewModel::checkAnswer
                            )
                        }
                    }

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
                            style = MaterialTheme.typography.bodyLarge,
                            color = when (uiState.feedback) {
                                AnswerFeedback.CORRECT -> Color(0xFF4CAF50)
                                AnswerFeedback.WRONG -> Color(0xFFF44336)
                                else -> Color(0xFFFFC107)
                            }
                        )
                    }
                }

                if (uiState.failureCount >= 3) {
                    TextButton(
                        onClick = { viewModel.onSkipExercise() },
                        modifier = Modifier.padding(bottom = 8.dp)
                    ) {
                        Text("Skip / Reveal Answer", color = MaterialTheme.colorScheme.secondary)
                    }
                }

                Button(
                    onClick = {
                        if (uiState.currentExerciseType == ExerciseType.READING) {
                            viewModel.onReadingContinue()
                        } else {
                            viewModel.checkAnswer()
                        }
                    },
                    enabled = (uiState.currentExerciseType == ExerciseType.READING) || 
                              (uiState.userInput.isNotBlank() && uiState.feedback == AnswerFeedback.NONE),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                ) {
                    Text(if (uiState.currentExerciseType == ExerciseType.READING) "Continue" else "Check")
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
        Text("Lesson Complete!", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(24.dp))
        Text("You mastered:", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(8.dp))
        masteredSenses.forEach { word ->
            Text(word, style = MaterialTheme.typography.bodyLarge)
        }
        Spacer(Modifier.height(32.dp))
        Button(onClick = onBackToMenu, modifier = Modifier.fillMaxWidth()) {
            Text("Back to Menu")
        }
    }
}

@Composable
private fun ExerciseHeader(progress: Float, progressText: String, phase: String, sessionXP: Int) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Left: question counter
            Text(progressText, style = MaterialTheme.typography.labelSmall)

            // Centre: phase badge
            Surface(
                color = MaterialTheme.colorScheme.tertiaryContainer,
                shape = MaterialTheme.shapes.extraSmall
            ) {
                Text(
                    text = phase,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                    color = MaterialTheme.colorScheme.onTertiaryContainer
                )
            }

            // Right: XP counter
            Surface(
                color = MaterialTheme.colorScheme.primaryContainer,
                shape = MaterialTheme.shapes.extraSmall
            ) {
                Text(
                    text = "⭐ $sessionXP XP",
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }
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
        AnswerFeedback.NONE -> MaterialTheme.colorScheme.primary
    }

    // Using FlowRow to allow sentence to wrap naturally
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.wrapContentHeight()
    ) {
        if (parts.getOrNull(0)?.isNotBlank() == true) {
            Text(text = "${parts[0]} ", style = MaterialTheme.typography.headlineSmall)
        }

        BasicTextField(
            value = userInput,
            onValueChange = onInputChanged,
            textStyle = MaterialTheme.typography.headlineSmall.copy(
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface
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
            Text(text = " ${parts[1]}", style = MaterialTheme.typography.headlineSmall)
        }
    }
}
