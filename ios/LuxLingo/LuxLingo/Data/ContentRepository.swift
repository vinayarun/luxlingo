import Foundation
import SwiftData

// MARK: - Content Repository (port of ContentRepository.kt)
@MainActor
final class ContentRepository: ObservableObject {
    let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
        seedDatabaseIfEmpty()
    }

    // MARK: - Seed Database

    private func seedDatabaseIfEmpty() {
        print("[LuxLingo] Checking if DB seeding is required (Deep Update)...")

        guard let url = Bundle.main.url(forResource: "initial_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[LuxLingo] Seed file not found in bundle")
            return
        }

        do {
            let decoder = JSONDecoder()
            let seedData = try decoder.decode(InitialSeedData.self, from: data)
            
            // ALPHA v3.2: Version-based forced re-seed
            let lastSeededVersion = UserDefaults.standard.double(forKey: "last_seeded_version")
            let currentLessons = db.getAllCurriculum().count
            
            let forceWipe = (seedData.version > lastSeededVersion) || (currentLessons == 0)
            
            if forceWipe {
                print("[LuxLingo] Seed Update Required (Version \(seedData.version) vs \(lastSeededVersion)). Wiping database.")
                
                // Full Wipe
                try? db.modelContext.delete(model: CurriculumEntity.self)
                try? db.modelContext.delete(model: LessonStatusEntity.self)
                try? db.modelContext.delete(model: SensesEntity.self)
                try? db.modelContext.delete(model: VocabularyEntity.self)
                try? db.modelContext.delete(model: SentencesEntity.self)
                try? db.modelContext.delete(model: UserProgressEntity.self)
                
                db.save()
            } else {
                print("[LuxLingo] Database is up to date (Version \(lastSeededVersion)). Skipping seed.")
                return
            }
            
            print("[LuxLingo] Deep Seed: Processing \(seedData.vocabulary.count) words, \(seedData.senses.count) senses, \(seedData.sentences.count) sentences.")

            // 1. Seed Vocabulary (Upsert)
            for v in seedData.vocabulary {
                db.insertVocabulary(VocabularyEntity(
                    surfaceId: v.surfaceId,
                    lemmaId: v.lemmaId,
                    wordText: v.wordLu,
                    audioRef: v.audioRef,
                    lodAudioUrl: v.lodAudioUrl
                ))
            }

            // 2. Seed Senses (Upsert)
            let encoder = JSONEncoder()
            for s in seedData.senses {
                let paradigmJson: String? = s.paradigm.flatMap { p in
                    (try? encoder.encode(p)).flatMap { String(data: $0, encoding: .utf8) }
                }
                db.insertSense(SensesEntity(
                    senseId: s.senseId,
                    surfaceId: s.surfaceId,
                    translations: s.primaryEn,
                    tags: s.pos,
                    isGoldenKey: s.isGoldenKey ?? false,
                    isPicturable: s.isPicturable ?? false,
                    paradigm: paradigmJson
                ))
            }

            // 3. Seed Sentences (Upsert)
            for sent in seedData.sentences {
                db.insertSentence(SentencesEntity(
                    sentenceId: sent.sentenceId,
                    textLu: sent.textLu,
                    textEn: sent.textEn,
                    senseIds: sent.senseIds.joined(separator: ","),
                    clozeIndex: sent.clozeIndex,
                    lexCoverage: 0.0,
                    synDensity: 0.0,
                    isHandcrafted: true,
                    difficulty: sent.difficulty,
                    nRuleWordIndex: sent.nRuleWordIndex,
                    nRuleForm: sent.nRuleForm,
                    exactForm: sent.exactForm ?? true
                ))
            }

            // 4. Seed Curriculum with Order Index
            for (index, curr) in seedData.curriculum.enumerated() {
                db.insertCurriculum(CurriculumEntity(
                    lessonId: curr.lessonId,
                    titleEn: curr.titleEn,
                    coreSenses: curr.coreSenses.joined(separator: ","),
                    secondarySenses: curr.secondarySenses?.joined(separator: ","),
                    orderIndex: index
                ))

                db.insertLessonStatus(LessonStatusEntity(
                    lessonId: curr.lessonId,
                    titleEn: curr.titleEn,
                    isCompleted: false,
                    mastery: 0,
                    completionPercentage: 0.0,
                    orderIndex: index
                ))
            }

            db.save()
            UserDefaults.standard.set(seedData.version, forKey: "last_seeded_version")
            print("[LuxLingo] Deep Seed Successful: All data synced with seed file (Version \(seedData.version)).")
        } catch {
            print("[LuxLingo] Seed Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Units / Curriculum

    func getUnits() -> [CourseUnit] {
        // trust the DB sort-descriptor
        let all = db.getAllCurriculum()
        
        print("[LuxLingo] Ordered Lessons: \(all.map { $0.lessonId }.joined(separator: ", "))")
        
        return all.map { curr in
            CourseUnit(
                id: curr.lessonId,
                title: curr.titleEn,
                lessons: []
            )
        }
    }

    // MARK: - Core Senses for a Lesson

    func getLessonCoreSenses(lessonId: String) -> [SensesEntity] {
        guard let curriculum = db.getCurriculum(lessonId) else { return [] }
        let senseIds = curriculum.coreSenses.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return senseIds.compactMap { db.getSense($0) }
    }

    // MARK: - Mastery Check

    func areAllCoreSensesMastered(lessonId: String) -> Bool {
        let coreSenses = getLessonCoreSenses(lessonId: lessonId)
        if coreSenses.isEmpty { return false }

        // Core Senses: Mastery >= 20 (approximate mastery for the sense)
        let coreMastered = coreSenses.allSatisfy { sense in
            let progress = db.getUserProgress(senseId: sense.senseId)
            let mastery = progress?.mastery ?? 0
            return mastery >= 20
        }

        // ALPHA v3.0: If core is mastered, we are done. Secondary exposure is a bonus but shouldn't block.
        return coreMastered
    }

    // MARK: - Record Exercise Result

    func recordExerciseResult(senseId: String, weight: Int, isCloze: Bool = false) {
        guard let sense = db.getSense(senseId) else { return }
        let userId = "default_user"

        let currentProgress = db.getUserProgress(senseId: senseId)
        let currentMastery = currentProgress?.mastery ?? 0
        let currentClozeExposure = currentProgress?.clozeExposure ?? 0

        // Bonus: boost first exposure for new words
        let actualWeight = (currentMastery == 0 && weight == 1) ? 3 : weight

        // Cap mastery at 0, no negative progress
        let newMastery = max(0, currentMastery + actualWeight)
        let newExposure = (currentProgress?.exposure ?? 0) + 1
        let newClozeExposure = (isCloze && weight > 0) ? currentClozeExposure + 1 : currentClozeExposure

        let progress = UserProgressEntity(
            userId: userId,
            senseId: senseId,
            surfaceId: sense.surfaceId,
            exposure: newExposure,
            mastery: newMastery,
            clozeExposure: newClozeExposure,
            lastError: currentProgress?.lastError,
            fsrsData: currentProgress?.fsrsData
        )

        db.insertUserProgress(progress)
        db.save()

        print("[LuxLingo] Mastery Update: Sense=\(senseId), Old=\(currentMastery), Added=\(actualWeight), New=\(newMastery), ClozeExp=\(newClozeExposure)")
    }

    // MARK: - Distractors

    // Broad POS group for distractor matching.
    // Pronouns and articles cluster together so MC options feel grammatically parallel.
    private func posGroup(_ tags: String) -> String {
        let t = tags.uppercased()
        if t.hasPrefix("PRON") || t.hasPrefix("ART") { return "pronoun" }
        if t.hasPrefix("VRB")                         { return "verb" }
        if t.hasPrefix("SUBST")                       { return "noun" }
        if t == "ADJ" || t == "ADV"                   { return "adjadv" }
        if t == "CONJ"                                { return "conj" }
        if t == "PREP"                                { return "prep" }
        return "other"
    }

    /// Returns distractors from the same POS group as the target sense.
    /// Falls back to random if the same-POS pool is too small.
    func getSmartDistractorsLu(target: String, senseId: String, count: Int) -> [String] {
        let allSenses = db.getAllSenses()
        let targetSense = allSenses.first { $0.senseId == senseId }
        let group = posGroup(targetSense?.tags ?? "other")

        let sameGroup: [String] = allSenses.compactMap { sense -> String? in
            guard sense.senseId != senseId,
                  posGroup(sense.tags) == group,
                  let vocab = db.getVocabularyById(sense.surfaceId),
                  vocab.wordText.lowercased() != target.lowercased() else { return nil }
            return vocab.wordText
        }

        if sameGroup.count >= count {
            return Array(sameGroup.shuffled().prefix(count))
        }
        // Fallback: any word that isn't the target
        return getRandomDistractorsLu(target: target, count: count)
    }

    func getRandomDistractorsLu(target: String, count: Int) -> [String] {
        let allSenses = db.getAllSenses()
        let pool: [String] = allSenses.compactMap { (sense: SensesEntity) -> String? in
            guard let vocab = db.getVocabularyById(sense.surfaceId) else { return nil }
            return vocab.wordText
        }
        .filter { (word: String) -> Bool in
            word.lowercased() != target.lowercased()
        }

        return Array(pool.shuffled().prefix(count))
    }

    func getRandomDistractorsEn(target: String, count: Int) -> [String] {
        let allSenses = db.getAllSenses()
        let lbChars = CharacterSet(charactersIn: "ëäüöéàâêîôûùèæœÿ")
        let pool: [String] = allSenses
            .map { sense -> String in sense.translations }
            .filter { word in
                word.lowercased() != target.lowercased()
                && word.unicodeScalars.allSatisfy { !lbChars.contains($0) }
            }

        return Array(pool.shuffled().prefix(count))
    }

    // MARK: - Sentence Selection (with Dynamic Buffer)

    func getSentenceForLesson(lessonId: String, excludeSentenceIds: [String] = [], targetSenseId: String? = nil) -> SentencesEntity? {
        let coreSenses: [SensesEntity]
        if let targetId = targetSenseId, let sense = db.getSense(targetId) {
            coreSenses = [sense]
        } else {
            coreSenses = getLessonCoreSenses(lessonId: lessonId)
        }

        if coreSenses.isEmpty {
            print("[LuxLingo] No core senses found for lesson \(lessonId)")
            return nil
        }

        // --- ALPHA v3.5: PRIORITY SELECTION ---
        // Prioritize senses that are not yet mastered (mastery < 20)
        let unmasteredSenses = coreSenses.filter { sense in
            let progress = db.getUserProgress(senseId: sense.senseId)
            return (progress?.mastery ?? 0) < 20
        }.shuffled()

        let masteredSenses = coreSenses.filter { sense in
            let progress = db.getUserProgress(senseId: sense.senseId)
            return (progress?.mastery ?? 0) >= 20
        }.shuffled()

        // Try unmastered first
        if let selected = pickSentenceFromSenses(unmasteredSenses, lessonId: lessonId, excludeSentenceIds: excludeSentenceIds) {
            return selected
        }

        // Fallback to mastered if unmastered pool is empty or has no valid sentences
        return pickSentenceFromSenses(masteredSenses, lessonId: lessonId, excludeSentenceIds: excludeSentenceIds)
    }

    private func pickSentenceFromSenses(_ senses: [SensesEntity], lessonId: String, excludeSentenceIds: [String]) -> SentencesEntity? {
        for sense in senses {
            let allSentences = db.getSentencesContainingSense(sense.senseId)
            if allSentences.isEmpty { continue }

            // 1. Determine target difficulty
            let lessonNum = Int(lessonId.replacingOccurrences(of: "lesson_", with: "")) ?? 1
            let allowedDifficulties = getAllowedDifficulties(lessonNum: lessonNum)

            // 2. Filter pool & ALIGN with target sense
            let pool = allSentences.filter { sentence in
                // Strict alignment: The sense we are targeting MUST be the primary target for this sentence
                let primaryTargetId = getSenseIdForCloze(sentence: sentence)
                let isAligned = primaryTargetId == sense.senseId
                let isDifficultyMet = allowedDifficulties.contains(sentence.difficulty)
                return isAligned && isDifficultyMet
            }
            
            let finalPool = pool.isEmpty ? allSentences.filter { getSenseIdForCloze(sentence: $0) == sense.senseId } : pool

            // 3. Buffer scaling & selection
            let dynamicBufferSize = min(8, finalPool.count / 2)
            let relevantExclusions = Set(excludeSentenceIds).intersection(finalPool.map { $0.sentenceId })
            
            let effectiveExclusions: [String] = (relevantExclusions.count > dynamicBufferSize) 
                ? Array(relevantExclusions.suffix(dynamicBufferSize))
                : Array(relevantExclusions)

            let validSentences = finalPool.filter { !effectiveExclusions.contains($0.sentenceId) }

            // For early lessons, only use sentences where the target word appears in its exact base form.
            // If all exact sentences are in the recency buffer, ignore recency rather than falling
            // back to conjugated/n-rule sentences — better to repeat than to confuse.
            let candidates: [SentencesEntity]
            if lessonNum <= 4 {
                let exactFromValid = validSentences.filter { $0.exactForm }
                if !exactFromValid.isEmpty {
                    candidates = exactFromValid
                } else {
                    // All exact sentences recently used — ignore recency, pick any exact sentence
                    let allExact = finalPool.filter { $0.exactForm }
                    candidates = allExact.isEmpty ? validSentences : allExact
                }
            } else {
                candidates = validSentences.isEmpty ? finalPool : validSentences
            }

            if let selected = candidates.randomElement() {
                print("[LuxLingo] Selection: Targeting \(sense.senseId), exactForm=\(selected.exactForm). Text: \(selected.textLu)")
                return selected
            }
        }
        return nil
    }

    private func getAllowedDifficulties(lessonNum: Int) -> [String] {
        if lessonNum <= 15 {
            return ["simple"]
        } else if lessonNum <= 35 {
            return Bool.random() ? ["simple"] : ["intermediate"]
        } else if lessonNum <= 50 {
            return Bool.random() ? ["intermediate"] : ["advanced"]
        } else {
            return ["advanced", "intermediate"]
        }
    }

    // MARK: - Cloze Sense ID

    func getSenseIdForCloze(sentence: SentencesEntity) -> String? {
        let ids = sentence.senseIds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if ids.isEmpty { return nil }

        let words = sentence.textLu.split(separator: " ").map { String($0) }
        let targetWord = words.indices.contains(sentence.clozeIndex)
            ? words[sentence.clozeIndex].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,?!:;\"() "))
            : nil

        guard let target = targetWord else { return ids.first }

        // Try to find the sense matching the target word
        for id in ids {
            guard let sense = db.getSense(id),
                  let vocab = db.getVocabularyById(sense.surfaceId) else { continue }
            let vocabWord = vocab.wordText.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,?!:;\"() "))
            if vocabWord == target {
                return id
            }
        }

        return ids.indices.contains(sentence.clozeIndex) ? ids[sentence.clozeIndex] : ids.first
    }

    // MARK: - Matching Pairs

    func getMatchingPairs(lessonId: String) -> [MatchingItemModel] {
        let coreSenses = getLessonCoreSenses(lessonId: lessonId)
        return coreSenses.compactMap { sense in
            guard let vocab = db.getVocabularyById(sense.surfaceId) else { return nil }
            return MatchingItemModel(
                id: sense.senseId,
                nativeText: vocab.wordText,
                translatedText: sense.translations
            )
        }
    }

    // MARK: - Mastery Helpers

    func getSenseMastery(senseId: String) -> Int {
        return db.getMastery(senseId: senseId)
    }

    func getSense(senseId: String) -> SensesEntity? {
        return db.getSense(senseId)
    }

    func getClozeExposure(senseId: String) -> Int {
        return db.getUserProgress(senseId: senseId)?.clozeExposure ?? 0
    }

    func getVocabularyById(id: String) -> VocabularyEntity? {
        return db.getVocabularyById(id)
    }

    // MARK: - Complete Lesson

    func completeLesson(lessonId: String) {
        let existing = db.getLessonStatus(lessonId)
        let status = LessonStatusEntity(
            lessonId: lessonId,
            titleEn: existing?.titleEn ?? "",
            isCompleted: true,
            mastery: existing?.mastery ?? 0,
            completionPercentage: 100.0
        )
        db.insertLessonStatus(status)
        db.save()
    }

    // MARK: - All Lesson Statuses

    func getAllLessonStatuses() -> [LessonStatusEntity] {
        return db.getAllLessonStatuses()
    }
}
