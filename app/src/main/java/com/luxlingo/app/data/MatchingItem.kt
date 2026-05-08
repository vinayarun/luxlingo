package com.luxlingo.app.data

data class MatchingItem(
    val senseId: String,
    val word: String,
    val translation: String,
    val isMatched: Boolean = false
)
