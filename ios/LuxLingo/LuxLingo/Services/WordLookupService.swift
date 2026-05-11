import Foundation

struct WordLookupResult {
    let word: String
    let translations: [String]
    let partOfSpeech: String?
}

@MainActor
final class WordLookupService {
    static let shared = WordLookupService()

    private var cache: [String: WordLookupResult] = [:]
    private var notFound: Set<String> = []
    private let baseURL = "https://lod.lu/api"

    private init() {}

    func lookup(word: String) async -> WordLookupResult? {
        let key = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard !key.isEmpty else { return nil }
        if let cached = cache[key] { return cached }
        if notFound.contains(key) { return nil }

        var result = await performLookup(word: key)
        // If the contraction map resolved to a different lemma, tag the result word as the original
        if result == nil { notFound.insert(key) }
        else { cache[key] = result }
        return result
    }

    // Short words that are contracted/reduced forms of longer lemmas and need a direct remapping.
    // "a" before consonants is the standard pre-consonant form of the conjunction "an" (and/in).
    private static let contractionMap: [String: String] = [
        "a": "an",   // conjunction: "Lena a Paul" = "Lena and Paul"
        "am": "an",  // preposition contraction: "am" = "an dem" (in the, masc/neut)
        "ass": "sinn", // 3rd person sg of sinn (to be): "Hien ass" = "He is"
    ]

    private func performLookup(word: String) async -> WordLookupResult? {
        // For known contractions, look up the base lemma directly
        let lookupWord = Self.contractionMap[word] ?? word

        guard let searchResults = await fetchSearchResults(for: lookupWord), !searchResults.isEmpty else { return nil }

        let wordLower = lookupWord.lowercased()
        let valid = searchResults.filter { ($0["erroneous"] as? Bool) != true }

        // All direct lemma hits (no cap) — covers full polysemy, e.g. Buch = book/account book/shoulder meat
        let directMatches = valid.filter { ($0["word_lb"] as? String)?.lowercased() == wordLower }
        var articleIds = directMatches.compactMap { $0["article_id"] as? String }

        // Base-form match — catches inflected adjectives/nouns where the query starts with the lemma.
        // e.g. "grousse" → "grouss" (ADJ), "groussen" → "grouss". Compound nouns (spaces in word_lb)
        // are excluded so "Grousse Seeëhr" (Great Egret) is never mistaken for the adjective.
        var usedIds = Set(articleIds)
        let baseFormMatch = valid.first { result in
            guard let wlb = result["word_lb"] as? String, !wlb.contains(" ") else { return false }
            let wlbLower = wlb.lowercased()
            guard wlbLower.count >= 4, wlbLower != wordLower else { return false }
            guard let id = result["article_id"] as? String, !usedIds.contains(id) else { return false }
            return wordLower.hasPrefix(wlbLower)
        }
        if let baseId = baseFormMatch?["article_id"] as? String {
            articleIds.insert(baseId, at: 0)  // base form goes first — most relevant meaning
            usedIds.insert(baseId)
        }

        // VRB form hit — handles conjugated verbs like "ass" → sinn (to be)
        let verbFormMatch = valid.first { result in
            guard let pos = result["pos"] as? String, pos.contains("VRB") else { return false }
            guard !(result["matches"] as? [String] ?? []).isEmpty else { return false }
            guard let id = result["article_id"] as? String, !usedIds.contains(id) else { return false }
            return (result["word_lb"] as? String)?.lowercased() != wordLower
        }
        if let verbId = verbFormMatch?["article_id"] as? String { articleIds.append(verbId) }

        // Fallback: no match found — prefer single-word results over compound nouns
        if articleIds.isEmpty {
            let singleWord = valid.filter { ($0["word_lb"] as? String)?.contains(" ") == false }
            articleIds = (singleWord.isEmpty ? valid : singleWord).prefix(2)
                .compactMap { $0["article_id"] as? String }
        }

        // Fetch all entries in parallel
        let firstPos = await withTaskGroup(of: (Int, [String], String?)?.self) { group in
            for (i, articleId) in articleIds.enumerated() {
                group.addTask { [baseURL = self.baseURL] in
                    guard let result = await WordLookupService.fetchTranslationsStatic(baseURL: baseURL, articleId: articleId) else { return nil }
                    return (i, result.0, result.1)
                }
            }
            var buckets = [Int: ([String], String?)]()
            for await item in group {
                if let (i, t, p) = item { buckets[i] = (t, p) }
            }
            return buckets
        }

        // Reassemble in original order so meaning #1 comes first
        var allTranslations: [String] = []
        var pos: String? = nil
        for i in articleIds.indices {
            if let (t, p) = firstPos[i] {
                allTranslations.append(contentsOf: t)
                if pos == nil { pos = p }
            }
        }

        var seen = Set<String>()
        let unique = allTranslations.filter { seen.insert($0.lowercased()).inserted }
        guard !unique.isEmpty else { return nil }
        return WordLookupResult(word: word, translations: unique, partOfSpeech: pos)
    }

    // Static helper so the task closure can call it without capturing self (avoids actor isolation issues)
    private static func fetchTranslationsStatic(baseURL: String, articleId: String) async -> ([String], String?)? {
        guard let url = URL(string: "\(baseURL)/en/entry/\(articleId)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let entryObj = json["entry"] as? [String: Any]
        let pos = entryObj?["partOfSpeechLabel"] as? String

        var translations: [String] = []
        if let microStructures = entryObj?["microStructures"] as? [[String: Any]],
           let firstMicro = microStructures.first,
           let gramUnits = firstMicro["grammaticalUnits"] as? [[String: Any]] {
            for gramUnit in gramUnits {
                guard let meanings = gramUnit["meanings"] as? [[String: Any]] else { continue }
                for meaning in meanings {
                    guard let targetLangs = meaning["targetLanguages"] as? [String: Any],
                          let en = targetLangs["en"] as? [String: Any],
                          let parts = en["parts"] as? [[String: Any]] else { continue }
                    translations.append(contentsOf: parts.compactMap { p -> String? in
                        guard (p["type"] as? String) == "translation" else { return nil }
                        return p["content"] as? String
                    })
                }
            }
        }
        guard !translations.isEmpty else { return nil }
        return (translations, pos)
    }

    private func fetchSearchResults(for word: String) async -> [[String: Any]]? {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/en/search?query=\(encoded)&lang=lb") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["results"] as? [[String: Any]]
    }

    private func fetchTranslations(articleId: String) async -> ([String], String?)? {
        guard let url = URL(string: "\(baseURL)/en/entry/\(articleId)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let entryObj = json["entry"] as? [String: Any]
        let pos = entryObj?["partOfSpeechLabel"] as? String

        var translations: [String] = []
        if let microStructures = entryObj?["microStructures"] as? [[String: Any]],
           let firstMicro = microStructures.first,
           let gramUnits = firstMicro["grammaticalUnits"] as? [[String: Any]] {
            for gramUnit in gramUnits {
                guard let meanings = gramUnit["meanings"] as? [[String: Any]] else { continue }
                for meaning in meanings {
                    guard let targetLangs = meaning["targetLanguages"] as? [String: Any],
                          let en = targetLangs["en"] as? [String: Any],
                          let parts = en["parts"] as? [[String: Any]] else { continue }
                    let t = parts.compactMap { p -> String? in
                        guard (p["type"] as? String) == "translation" else { return nil }
                        return p["content"] as? String
                    }
                    translations.append(contentsOf: t)
                }
            }
        }

        guard !translations.isEmpty else { return nil }
        return (translations, pos)
    }
}
