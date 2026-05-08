import Foundation

struct EifelerRegel {
    /// The "UNITED ZOHA" consonants and all vowels.
    /// If a word starts with one of these, the preceding 'n' is kept.
    private static let keptInitialLetters = CharacterSet(charactersIn: "unitedzohaUNITEDZOHA")
    private static let vowels = CharacterSet(charactersIn: "aeiouäëéAEIOUÄËÉ")
    
    /// Determines if the final 'n' should be kept.
    /// - Parameters:
    ///   - followingWord: The word that comes immediately after the word ending in 'n'.
    ///   - isEndOfSentence: True if the word is at the very end of the sentence.
    /// - Returns: True if the 'n' should be kept.
    static func shouldKeepN(followingWord: String?, isEndOfSentence: Bool) -> Bool {
        // Rule: Always keep 'n' at the end of a sentence.
        if isEndOfSentence || followingWord == nil || followingWord?.isEmpty == true {
            return true
        }
        
        guard let firstChar = followingWord?.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return true
        }
        
        let firstLetter = String(firstChar)
        
        // Rule: Keep 'n' before vowels and the consonants d, h, n, t, z.
        // The "UNITED ZOHA" mnemonic covers all vowels + d, h, n, t, z.
        if firstLetter.rangeOfCharacter(from: keptInitialLetters) != nil {
            return true
        }
        
        // Additional check for vowels not in the basic "UNITED ZOHA" (like ä, ë, é)
        if firstLetter.rangeOfCharacter(from: vowels) != nil {
            return true
        }
        
        return false
    }
    
    /// Normalizes a word by removing the potentially droppable 'n' if the rule dictates it.
    /// This is useful for checking user input.
    static func applyRule(to word: String, followingWord: String?, isEndOfSentence: Bool) -> String {
        guard word.lowercased().hasSuffix("n") else {
            return word
        }
        
        if shouldKeepN(followingWord: followingWord, isEndOfSentence: isEndOfSentence) {
            return word
        } else {
            return String(word.dropLast())
        }
    }
}
