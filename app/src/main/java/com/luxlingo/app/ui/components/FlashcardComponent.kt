package com.luxlingo.app.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.luxlingo.app.model.Exercise

@Composable
fun FlashcardExercise(
    targetWord: String,
    translation: String,
    exampleSentenceLu: String = "",
    exampleSentenceEn: String = "",
    onContinue: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "New Word!",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        Card(
            modifier = Modifier
                .fillMaxWidth()
                .height(350.dp) // Increased height for more content
                .padding(vertical = 8.dp),
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                // Luxembourgish word (Header)
                Text(
                    text = targetWord,
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                    textAlign = TextAlign.Center
                )

                // English Translation (Body)
                Text(
                    text = translation,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 8.dp)
                )

                Divider(
                    modifier = Modifier
                        .width(100.dp)
                        .padding(vertical = 24.dp),
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.2f)
                )

                // Luxembourgish Example Sentence (Footer)
                if (exampleSentenceLu.isNotEmpty()) {
                    Text(
                        text = exampleSentenceLu,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        textAlign = TextAlign.Center,
                        fontWeight = FontWeight.Medium
                    )
                    
                    // English Translation of example (Sub-caption)
                    if (exampleSentenceEn.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = exampleSentenceEn,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.6f),
                            textAlign = TextAlign.Center,
                            fontStyle = androidx.compose.ui.text.font.FontStyle.Italic
                        )
                    }
                }
                
                Spacer(modifier = Modifier.height(24.dp))
                
                // Audio placeholder (Icon)
                Icon(
                    imageVector = androidx.compose.material.icons.Icons.Default.PlayArrow,
                    contentDescription = "Play Audio",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(32.dp)
                )
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        LuxlingoButton(
            text = "I've learned it",
            onClick = onContinue,
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 32.dp)
                .height(56.dp)
        )
    }
}
