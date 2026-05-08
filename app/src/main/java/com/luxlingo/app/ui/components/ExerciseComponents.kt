package com.luxlingo.app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.luxlingo.app.model.Exercise
import com.luxlingo.app.model.MatchingItem
import com.luxlingo.app.ui.FeedbackState

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MatchingExercise(
    pairs: List<MatchingItem>,
    onComplete: () -> Unit
) {
    var selectedId by remember { mutableStateOf<String?>(null) }
    var matchedIds by remember { mutableStateOf(setOf<String>()) }

    // Flatten pairs into individual cards and shuffle once
    data class CardData(val id: String, val text: String, val pairId: String)
    val cards = remember(pairs) {
        pairs.flatMap {
            listOf(
                CardData("${it.id}_LU", it.nativeText, it.id),
                CardData("${it.id}_EN", it.translatedText, it.id)
            )
        }.shuffled()
    }

    LaunchedEffect(matchedIds) {
        if (matchedIds.size == cards.size && cards.isNotEmpty()) {
            onComplete()
        }
    }

    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        cards.forEach { card ->
            val isMatched = card.id in matchedIds
            val isSelected = card.id == selectedId

            AnimatedVisibility(visible = !isMatched) {
                LuxlingoButton(
                    text = card.text,
                    onClick = {
                        if (selectedId == null) {
                            selectedId = card.id
                        } else if (selectedId != card.id) {
                            // Check match
                            val prev = cards.find { it.id == selectedId }
                            if (prev != null && prev.pairId == card.pairId) {
                                matchedIds = matchedIds + card.id + prev.id
                                selectedId = null
                            } else {
                                selectedId = null // Reset on mismatch (could add shake animation here)
                            }
                        }
                    },
                    isSelected = isSelected,
                    modifier = Modifier.widthIn(min = 100.dp).height(60.dp)
                )
            }
        }
    }
}

@Composable
fun MCQExercise(
    exercise: Exercise,
    onAnswerSelected: (String) -> Unit,
    feedbackState: FeedbackState = FeedbackState.None
) {
    var selectedAnswer by remember { mutableStateOf<String?>(null) }
    
    // Logic: If clozeIndex is present, mask the target word in the prompt
    val displayPrompt = remember(exercise.prompt, exercise.clozeIndex) {
        val words = exercise.prompt.split(" ")
        val index = exercise.clozeIndex
        if (index != null && index in words.indices) {
            val mutableWords = words.toMutableList()
            mutableWords[index] = "______"
            mutableWords.joinToString(" ")
        } else {
            exercise.prompt
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Prompt - English text (smaller, secondary)
        Text(
            text = displayPrompt,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 32.dp),
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Options with feedback states
        exercise.options?.forEach { option ->
            val isSelected = selectedAnswer == option
            val isCorrect = when {
                feedbackState is FeedbackState.Correct && isSelected -> true
                feedbackState is FeedbackState.Incorrect && isSelected -> false
                feedbackState is FeedbackState.Incorrect && option == exercise.correctAnswer -> true
                else -> null
            }
            
            AnimatedVisibility(
                visible = true,
                enter = fadeIn() + slideInVertically(
                    initialOffsetY = { it },
                    animationSpec = tween(300)
                ),
                exit = fadeOut() + slideOutVertically(
                    targetOffsetY = { it },
                    animationSpec = tween(300)
                )
            ) {
                LuxlingoButton(
                    text = option,
                    onClick = {
                        if (feedbackState is FeedbackState.None) {
                            selectedAnswer = option
                            onAnswerSelected(option)
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    enabled = feedbackState is FeedbackState.None,
                    isSelected = isSelected,
                    isCorrect = isCorrect
                )
            }
        }
    }
}

@Composable
fun FillInBlankExercise(
    exercise: Exercise,
    onAnswerSelected: (String) -> Unit,
    feedbackState: FeedbackState = FeedbackState.None
) {
    var selectedWord by remember { mutableStateOf<String?>(null) }
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Sentence with blank - Luxembourgish text (large, bold)
        val displaySentence = remember(exercise.prompt, exercise.clozeIndex, selectedWord) {
            val words = exercise.prompt.split(" ")
            val index = exercise.clozeIndex ?: 0 // Default to 0 if null to prevent crash
            
            if (index in words.indices) {
                val mutableWords = words.toMutableList()
                mutableWords[index] = selectedWord ?: "____"
                mutableWords.joinToString(" ")
            } else {
                exercise.prompt // Fallback
            }
        }

        Text(
            text = displaySentence,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(bottom = 8.dp),
            textAlign = TextAlign.Center,
            lineHeight = 40.sp
        )
        
        // English translation hint (smaller, secondary)
        Text(
            text = "Fill in the blank",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 32.dp)
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Word options
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            exercise.options?.forEach { option ->
                val isSelected = selectedWord == option
                val isCorrect = when {
                    feedbackState is FeedbackState.Correct && isSelected -> true
                    feedbackState is FeedbackState.Incorrect && isSelected -> false
                    feedbackState is FeedbackState.Incorrect && option == exercise.correctAnswer -> true
                    else -> null
                }
                
                AnimatedVisibility(
                    visible = true,
                    enter = fadeIn() + slideInVertically(
                        initialOffsetY = { it },
                        animationSpec = tween(300)
                    )
                ) {
                    LuxlingoButton(
                        text = option,
                        onClick = {
                            if (feedbackState is FeedbackState.None) {
                                selectedWord = option
                                onAnswerSelected(option)
                            }
                        },
                        modifier = Modifier.weight(1f),
                        enabled = feedbackState is FeedbackState.None,
                        isSelected = isSelected,
                        isCorrect = isCorrect
                    )
                }
            }
        }
    }
}

@Composable
fun TranslateExercise(
    exercise: Exercise,
    onAnswerSelected: (String) -> Unit,
    feedbackState: FeedbackState = FeedbackState.None
) {
    var userAnswer by remember { mutableStateOf("") }
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // English prompt (smaller, secondary)
        Text(
            text = "Translate to Luxembourgish:",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 8.dp)
        )
        
        // English sentence (medium, regular)
        Text(
            text = exercise.prompt,
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(bottom = 32.dp),
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Answer display area
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(
                    when {
                        feedbackState is FeedbackState.Correct -> Color(0xFFD7FFB8)
                        feedbackState is FeedbackState.Incorrect -> Color(0xFFFFD7D7)
                        else -> MaterialTheme.colorScheme.surfaceVariant
                    },
                    RoundedCornerShape(20.dp)
                )
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            if (feedbackState !is FeedbackState.None) {
                // Show correct answer
                Text(
                    text = exercise.correctAnswer,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center
                )
            } else {
                Text(
                    text = "Type your answer",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            }
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        // Word bank (if we want to add it later)
        // For now, this is a simple translate exercise
        Text(
            text = "Tap to reveal answer",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .clickable(enabled = feedbackState is FeedbackState.None) {
                    onAnswerSelected(exercise.correctAnswer)
                }
                .padding(16.dp)
        )
    }
}

@Composable
fun ReorderExercise(
    exercise: Exercise,
    onAnswerSelected: (String) -> Unit,
    feedbackState: FeedbackState = FeedbackState.None
) {
    var currentSentence by remember { mutableStateOf(listOf<String>()) }
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Prompt - English (smaller, secondary)
        Text(
            text = exercise.prompt,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 8.dp),
            textAlign = TextAlign.Center
        )
        
        // Answer Area - Luxembourgish (large, bold)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(
                    MaterialTheme.colorScheme.surfaceVariant,
                    RoundedCornerShape(20.dp)
                )
                .padding(24.dp)
                .height(80.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = if (currentSentence.isEmpty()) "Tap words to build sentence" else currentSentence.joinToString(" "),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = if (currentSentence.isEmpty()) 
                    MaterialTheme.colorScheme.onSurfaceVariant 
                else 
                    MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center
            )
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        // Word options
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            exercise.options?.forEach { word ->
                if (!currentSentence.contains(word)) {
                    AnimatedVisibility(
                        visible = true,
                        enter = fadeIn() + slideInVertically(
                            initialOffsetY = { it },
                            animationSpec = tween(300)
                        )
                    ) {
                        LuxlingoButton(
                            text = word,
                            onClick = {
                                if (feedbackState is FeedbackState.None) {
                                    val newSentence = currentSentence + word
                                    currentSentence = newSentence
                                    // Check if sentence matches length of options
                                    if (newSentence.size == exercise.options.size) {
                                        onAnswerSelected(newSentence.joinToString(" "))
                                    }
                                }
                            },
                            modifier = Modifier.weight(1f),
                            enabled = feedbackState is FeedbackState.None
                        )
                    }
                }
            }
        }
        
        if (currentSentence.isNotEmpty() && feedbackState is FeedbackState.None) {
            Spacer(modifier = Modifier.height(16.dp))
            TextButton(
                onClick = { currentSentence = emptyList() },
                modifier = Modifier.padding(top = 8.dp)
            ) {
                Text("Reset", color = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
fun MatchExercise(
    exercise: Exercise,
    onAnswerSelected: (String) -> Unit,
    feedbackState: FeedbackState = FeedbackState.None
) {
    // Check if this is an introduction exercise (prompt contains "=")
    val isIntroduction = exercise.prompt.contains("=")
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (isIntroduction) {
            // Introduction/Learning card
            val parts = exercise.prompt.split("=")
            val word = parts.getOrNull(0)?.trim() ?: ""
            val translation = parts.getOrNull(1)?.trim() ?: ""
            val options = exercise.options ?: emptyList()
            val exampleLb = options.getOrNull(2) ?: ""
            val exampleEn = options.getOrNull(3) ?: ""
            
            Text(
                text = "Learn this word:",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            
            // Word card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                )
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Luxembourgish word (large, bold)
                    Text(
                        text = word,
                        style = MaterialTheme.typography.displaySmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    
                    // Translation
                    Text(
                        text = translation,
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(bottom = 16.dp)
                    )
                    
                    Divider(modifier = Modifier.padding(vertical = 8.dp))
                    
                    // Examples
                    if (exampleLb.isNotEmpty()) {
                        Text(
                            text = exampleLb,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(bottom = 4.dp),
                            textAlign = TextAlign.Center
                        )
                    }
                    if (exampleEn.isNotEmpty()) {
                        Text(
                            text = exampleEn,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        } else {
            // Regular match exercise
            Text(
                text = exercise.prompt,
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.padding(bottom = 24.dp),
                textAlign = TextAlign.Center
            )
            
            val pairs = exercise.options?.chunked(2) ?: emptyList()
            
            pairs.forEachIndexed { index, pair ->
                if (pair.size == 2) {
                    AnimatedVisibility(
                        visible = true,
                        enter = fadeIn() + slideInVertically(
                            initialOffsetY = { it },
                            animationSpec = tween(300, delayMillis = index * 100)
                        )
                    ) {
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp),
                            shape = RoundedCornerShape(20.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant
                            )
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(20.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                // Luxembourgish word (large, bold)
                                Text(
                                    text = pair[0],
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "→",
                                    style = MaterialTheme.typography.titleLarge,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                // English translation (medium)
                                Text(
                                    text = pair[1],
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        LuxlingoButton(
            text = if (isIntroduction) "Got it!" else "Continue",
            onClick = { onAnswerSelected("pairs") },
            modifier = Modifier.fillMaxWidth(),
            enabled = feedbackState is FeedbackState.None
        )
    }
}
@Composable
fun LuxlingoButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isSelected: Boolean = false,
    isCorrect: Boolean? = null
) {
    val backgroundColor = when {
        isCorrect == true -> Color(0xFF4CAF50) // Green
        isCorrect == false -> Color(0xFFF44336) // Red
        isSelected -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.surfaceVariant
    }

    val contentColor = when {
        isCorrect != null -> Color.White
        isSelected -> MaterialTheme.colorScheme.onPrimary
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Button(
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(
            containerColor = backgroundColor,
            contentColor = contentColor,
            disabledContainerColor = backgroundColor.copy(alpha = 0.5f),
            disabledContentColor = contentColor.copy(alpha = 0.5f)
        ),
        shape = RoundedCornerShape(12.dp),
        elevation = ButtonDefaults.buttonElevation(
            defaultElevation = 4.dp,
            pressedElevation = 2.dp
        )
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun JumbledWordRow(
    availableTokens: List<String>,
    selectedTokens: List<String>,
    onTokenSelected: (String) -> Unit,
    onTokenRemoved: (String) -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Selected Tokens Area (Sentence construction)
        FlowRow(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 60.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp))
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (selectedTokens.isEmpty()) {
                Text(
                    text = "Tap words to build sentence",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                )
            } else {
                selectedTokens.forEach { token ->
                    LuxlingoButton(
                        text = token,
                        onClick = { onTokenRemoved(token) },
                        modifier = Modifier.height(40.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Available Tokens Area (Word Bank)
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Only show tokens that haven't been selected yet (or show duplicates if needed logic allows)
            // Simple logic: Count occurrences in available vs selected
            val selectedCounts = selectedTokens.groupingBy { it }.eachCount()
            val availableCounts = availableTokens.groupingBy { it }.eachCount()

            availableTokens.distinct().forEach { token ->
                val usedCount = selectedCounts[token] ?: 0
                val totalCount = availableCounts[token] ?: 0
                
                if (usedCount < totalCount) {
                     LuxlingoButton(
                        text = token,
                        onClick = { onTokenSelected(token) },
                        modifier = Modifier.height(40.dp)
                    )
                }
            }
        }
    }
}
