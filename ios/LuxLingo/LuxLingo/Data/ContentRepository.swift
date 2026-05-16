import Foundation
import SwiftData

// MARK: - Content Repository (port of ContentRepository.kt)
@MainActor
final class ContentRepository: ObservableObject {
    let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
        // Seeding is now async — caller must invoke seedIfNeeded() after init.
    }

    // MARK: - Seed Database

    /// Async seed: uses direct inserts (no per-record fetch) and yields between
    /// batches so the main-thread watchdog is never triggered.
    func seedIfNeeded() async {
        guard let url = Bundle.main.url(forResource: "initial_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[LuxLingo] Seed file not found in bundle")
            return
        }

        guard let seedData = try? JSONDecoder().decode(InitialSeedData.self, from: data) else {
            print("[LuxLingo] Failed to decode seed file")
            return
        }

        let lastSeededVersion = UserDefaults.standard.double(forKey: "last_seeded_version")
        let currentLessons = db.getAllCurriculum().count
        guard seedData.version > lastSeededVersion || currentLessons == 0 else {
            print("[LuxLingo] DB up to date (v\(lastSeededVersion)). Skipping seed.")
            return
        }

        print("[LuxLingo] Seed required v\(lastSeededVersion)→v\(seedData.version). Wiping DB...")

        try? db.modelContext.delete(model: CurriculumEntity.self)
        try? db.modelContext.delete(model: LessonStatusEntity.self)
        try? db.modelContext.delete(model: SensesEntity.self)
        try? db.modelContext.delete(model: VocabularyEntity.self)
        try? db.modelContext.delete(model: SentencesEntity.self)
        try? db.modelContext.delete(model: UserProgressEntity.self)
        try? db.modelContext.delete(model: ArticleExerciseEntity.self)
        db.save()
        await Task.yield()

        print("[LuxLingo] Seeding \(seedData.vocabulary.count) words, \(seedData.senses.count) senses, \(seedData.sentences.count) sentences...")

        // 1. Vocabulary — direct insert, no fetch (DB is empty after wipe)
        for v in seedData.vocabulary {
            db.modelContext.insert(VocabularyEntity(
                surfaceId: v.surfaceId,
                lemmaId: v.lemmaId,
                wordText: v.wordLu,
                audioRef: v.audioRef,
                lodAudioUrl: v.lodAudioUrl
            ))
        }
        db.save()
        await Task.yield()

        // 2. Senses
        let encoder = JSONEncoder()
        for s in seedData.senses {
            let paradigmJson = s.paradigm.flatMap { p in
                (try? encoder.encode(p)).flatMap { String(data: $0, encoding: .utf8) }
            }
            db.modelContext.insert(SensesEntity(
                senseId: s.senseId,
                surfaceId: s.surfaceId,
                translations: s.primaryEn,
                tags: s.pos,
                isGoldenKey: s.isGoldenKey ?? false,
                isPicturable: s.isPicturable ?? false,
                paradigm: paradigmJson
            ))
        }
        db.save()
        await Task.yield()

        // 3. Sentences — batch saves every 500 rows to cap memory pressure
        for (i, sent) in seedData.sentences.enumerated() {
            db.modelContext.insert(SentencesEntity(
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
            if i % 500 == 499 {
                db.save()
                await Task.yield()
            }
        }
        db.save()
        await Task.yield()

        // 4. Curriculum (core lessons)
        for (index, curr) in seedData.curriculum.enumerated() {
            // Derive unit index from lesson number: lesson_N → (N-1)/7
            let lessonNum = Int(curr.lessonId.replacingOccurrences(of: "lesson_", with: "")) ?? 1
            let derivedUnitIndex = (lessonNum - 1) / 7
            db.modelContext.insert(CurriculumEntity(
                lessonId: curr.lessonId,
                titleEn: curr.titleEn,
                coreSenses: curr.coreSenses.joined(separator: ","),
                secondarySenses: curr.secondarySenses?.joined(separator: ","),
                orderIndex: index,
                lessonType: "core",
                situationTag: nil,
                unitIndex: derivedUnitIndex
            ))
            db.modelContext.insert(LessonStatusEntity(
                lessonId: curr.lessonId,
                titleEn: curr.titleEn,
                isCompleted: false,
                mastery: 0,
                completionPercentage: 0.0,
                orderIndex: index
            ))
        }
        db.save()
        await Task.yield()

        // 5. Article Exercises
        if let articleExercises = seedData.articleExercises {
            let encoder = JSONEncoder()
            for ex in articleExercises {
                let optionsJson = (try? encoder.encode(ex.options)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                db.modelContext.insert(ArticleExerciseEntity(
                    exerciseId: ex.id,
                    senseId: ex.senseId,
                    textLu: ex.textLu,
                    textEn: ex.textEn,
                    articleIndex: ex.articleIndex,
                    correct: ex.correct,
                    options: optionsJson,
                    ruleHint: ex.ruleHint,
                    difficulty: ex.difficulty
                ))
            }
            db.save()
            await Task.yield()
        }

        // 6. Bonus Lessons
        if let bonusLessons = seedData.bonusLessons {
            let bonusOffset = seedData.curriculum.count
            for (index, bonus) in bonusLessons.enumerated() {
                db.modelContext.insert(CurriculumEntity(
                    lessonId: bonus.lessonId,
                    titleEn: bonus.titleEn,
                    coreSenses: bonus.coreSenses.joined(separator: ","),
                    themeTag: bonus.sceneImage,    // store sceneImage name in themeTag
                    orderIndex: bonusOffset + index,
                    lessonType: "bonus",
                    situationTag: bonus.situationTag,
                    unitIndex: bonus.unitIndex
                ))
                db.modelContext.insert(LessonStatusEntity(
                    lessonId: bonus.lessonId,
                    titleEn: bonus.titleEn,
                    isCompleted: false,
                    mastery: 0,
                    completionPercentage: 0.0,
                    orderIndex: bonusOffset + index
                ))
            }
            db.save()
        }

        UserDefaults.standard.set(seedData.version, forKey: "last_seeded_version")
        print("[LuxLingo] Seed complete v\(seedData.version).")
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
                && !word.contains(" ")   // exclude multi-word phrases — they split badly in jumbled exercises
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

            // For early lessons, prefer sentences where the target word appears in its exact base form
            // (not conjugated or n-rule modified). But if fewer than 3 exact-form sentences exist
            // in the pool, fall back to all valid sentences — better variety than repeating 2 sentences
            // For early lessons prefer the base/exact form of the word. Never fall back to
            // conjugated sentences — better to repeat than to confuse beginners.
            let candidates: [SentencesEntity]
            if lessonNum <= 4 {
                let exactFromValid = validSentences.filter { $0.exactForm }
                if !exactFromValid.isEmpty {
                    candidates = exactFromValid
                } else {
                    // All exact sentences are in the recency buffer — ignore recency.
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

    func getMatchingPairs(lessonId: String, count: Int = 4) -> [MatchingItemModel] {
        let coreSenses = getLessonCoreSenses(lessonId: lessonId).shuffled()
        return coreSenses.compactMap { sense -> MatchingItemModel? in
            guard let vocab = db.getVocabularyById(sense.surfaceId) else { return nil }
            return MatchingItemModel(
                id: sense.senseId,
                nativeText: vocab.wordText,
                translatedText: sense.translations
            )
        }
        .prefix(count)
        .shuffled()
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

    // MARK: - Vocabulary browser & Review mode

    /// All encountered words (mastery > 0) across the given lesson IDs, sorted A-Z.
    func getEncounteredVocab(for lessonIds: [String]) -> [VocabWord] {
        var seen   = Set<String>()
        var result = [VocabWord]()
        for lessonId in lessonIds {
            for sense in getLessonCoreSenses(lessonId: lessonId) {
                guard !seen.contains(sense.senseId) else { continue }
                seen.insert(sense.senseId)
                let mastery = getSenseMastery(senseId: sense.senseId)
                guard mastery > 0, let vocab = getVocabularyById(id: sense.surfaceId) else { continue }
                let sentence = getSentenceForLesson(lessonId: lessonId, targetSenseId: sense.senseId)
                result.append(VocabWord(
                    senseId:     sense.senseId,
                    wordLu:      vocab.wordText,
                    primaryEn:   sense.translations,
                    exampleLu:   sentence?.textLu ?? "",
                    exampleEn:   sentence?.textEn ?? "",
                    mastery:     mastery,
                    lodAudioUrl: vocab.lodAudioUrl
                ))
            }
        }
        return result.sorted { $0.wordLu.localizedCaseInsensitiveCompare($1.wordLu) == .orderedAscending }
    }

    /// Total encountered word count — shown on the home-screen Review card.
    func reviewableWordCount() -> Int {
        var seen = Set<String>(); var count = 0
        for status in getAllLessonStatuses() {
            for sense in getLessonCoreSenses(lessonId: status.lessonId) {
                guard !seen.contains(sense.senseId) else { continue }
                seen.insert(sense.senseId)
                if getSenseMastery(senseId: sense.senseId) > 0 { count += 1 }
            }
        }
        return count
    }

    /// 3-bucket review queue so every session balances weak words, consolidation, and long-term retention.
    ///
    /// Bucket A (~60 %): lowest mastery — words still being learned.
    /// Bucket B (~20 %): medium mastery — solidifying knowledge.
    /// Bucket C (~20 %): random draw from all encountered words, including fully mastered —
    ///                   prevents forgetting of older vocabulary.
    ///
    /// Within A and B, older lessons are preferred over same-mastery recent ones
    /// so that early vocabulary doesn't silently decay once newer lessons push it out.
    func buildReviewQueue(limit: Int = 10) -> [(senseId: String, lessonId: String)] {
        struct Entry { let senseId: String; let lessonId: String; let mastery: Int; let lessonNum: Int }

        var seen = Set<String>()
        var all = [Entry]()

        // Collect all encountered words, ordered by lesson completion (oldest first)
        let statuses = getAllLessonStatuses().sorted {
            let a = Int($0.lessonId.replacingOccurrences(of: "lesson_", with: "")) ?? 0
            let b = Int($1.lessonId.replacingOccurrences(of: "lesson_", with: "")) ?? 0
            return a < b
        }
        for status in statuses {
            let lessonNum = Int(status.lessonId.replacingOccurrences(of: "lesson_", with: "")) ?? 0
            for sense in getLessonCoreSenses(lessonId: status.lessonId) {
                guard !seen.contains(sense.senseId) else { continue }
                seen.insert(sense.senseId)
                let m = getSenseMastery(senseId: sense.senseId)
                if m > 0 { all.append(Entry(senseId: sense.senseId, lessonId: status.lessonId, mastery: m, lessonNum: lessonNum)) }
            }
        }

        guard !all.isEmpty else { return [] }

        // Sort by mastery asc, then by lesson age desc (older lesson = higher priority within same mastery)
        let sorted = all.sorted {
            if $0.mastery != $1.mastery { return $0.mastery < $1.mastery }
            return $0.lessonNum < $1.lessonNum
        }

        let bucketA = max(1, Int(Double(limit) * 0.60))   // weakest
        let bucketB = max(1, Int(Double(limit) * 0.20))   // medium
        let bucketC = limit - bucketA - bucketB            // random from all

        var result = [Entry]()
        var usedIds = Set<String>()

        // A: lowest mastery
        for e in sorted.prefix(bucketA) {
            result.append(e); usedIds.insert(e.senseId)
        }

        // B: medium band (skip what A already took)
        let midStart = min(bucketA, sorted.count)
        let midEnd   = min(bucketA + bucketB * 3, sorted.count)  // look ahead to find B candidates
        for e in sorted[midStart..<midEnd] where !usedIds.contains(e.senseId) {
            if result.filter({ $0.mastery >= 10 && $0.mastery < 20 }).count < bucketB {
                result.append(e); usedIds.insert(e.senseId)
            }
        }

        // C: random from all (including fully mastered) to prevent forgetting
        let remaining = all.filter { !usedIds.contains($0.senseId) }.shuffled()
        for e in remaining.prefix(bucketC) {
            result.append(e); usedIds.insert(e.senseId)
        }

        // Cap and shuffle so the order inside each bucket isn't predictable
        return result.prefix(limit).map { ($0.senseId, $0.lessonId) }.shuffled()
    }

    // MARK: - Article Exercises

    func getArticleExercise(for senseId: String) -> ArticleExerciseEntity? {
        let exercises = (try? db.modelContext.fetch(
            FetchDescriptor<ArticleExerciseEntity>(
                predicate: #Predicate { $0.senseId == senseId }
            )
        )) ?? []
        return exercises.randomElement()
    }

    // MARK: - Bonus Lessons

    func getBonusLessons() -> [CurriculumEntity] {
        let all = (try? db.modelContext.fetch(
            FetchDescriptor<CurriculumEntity>(
                predicate: #Predicate { $0.lessonType == "bonus" },
                sortBy: [SortDescriptor(\.unitIndex)]
            )
        )) ?? []
        return all
    }

    func isBonusLessonUnlocked(unitIndex: Int) -> Bool {
        let coreLessons = (try? db.modelContext.fetch(
            FetchDescriptor<CurriculumEntity>(
                predicate: #Predicate { $0.lessonType == "core" && $0.unitIndex == unitIndex }
            )
        )) ?? []
        let completedCount = coreLessons.filter { lesson in
            let status = db.getLessonStatus(lesson.lessonId)
            return status?.isCompleted == true
        }.count
        return completedCount >= 4
    }
}
