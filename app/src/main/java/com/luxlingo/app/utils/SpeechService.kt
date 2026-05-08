package com.luxlingo.app.utils

interface SpeechService {
    fun speak(text: String)
    fun transcribe(): String
}

class MockSpeechService : SpeechService {
    override fun speak(text: String) {
        // Placeholder for TTS
        println("Speaking: $text")
    }

    override fun transcribe(): String {
        // Placeholder for STT
        return ""
    }
}
