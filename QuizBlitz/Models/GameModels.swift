import Foundation
import CouchbaseLiteSwift

// MARK: - Game Phase

enum GamePhase: String, Codable {
    case lobby
    case asking
    case closed
    case finished
}

// MARK: - Game

class Game: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var joinCode: String
    var phase: GamePhase
    var questionCount: Int
    var createdAt: Date

    init(title: String, joinCode: String, phase: GamePhase = .lobby, questionCount: Int = 0, createdAt: Date = Date()) {
        self.title = title
        self.joinCode = joinCode
        self.phase = phase
        self.questionCount = questionCount
        self.createdAt = createdAt
    }
}

// MARK: - Player

class Player: Codable, Identifiable {
    @DocumentID var id: String?
    var gameId: String
    var displayName: String
    var joinedAt: Date

    init(gameId: String, displayName: String, joinedAt: Date = Date()) {
        self.gameId = gameId
        self.displayName = displayName
        self.joinedAt = joinedAt
    }
}

// MARK: - Question

class Question: Codable, Identifiable {
    @DocumentID var id: String?
    var gameId: String
    var index: Int
    var text: String
    var choices: [String]
    var correctChoiceIndex: Int
    var timeLimitSeconds: Int

    init(gameId: String, index: Int, text: String, choices: [String], correctChoiceIndex: Int, timeLimitSeconds: Int = 15) {
        self.gameId = gameId
        self.index = index
        self.text = text
        self.choices = choices
        self.correctChoiceIndex = correctChoiceIndex
        self.timeLimitSeconds = timeLimitSeconds
    }
}

// MARK: - Question State (host-controlled)

class QuestionState: Codable {
    @DocumentID var id: String?
    var gameId: String
    var currentQuestionId: String?
    var currentQuestionIndex: Int
    var phase: GamePhase
    var questionStartSeq: Int
    var questionStartHostUptimeNs: UInt64
    var closeAtHostUptimeNs: UInt64

    init(gameId: String, currentQuestionId: String? = nil, currentQuestionIndex: Int = 0,
         phase: GamePhase = .lobby, questionStartSeq: Int = 0,
         questionStartHostUptimeNs: UInt64 = 0, closeAtHostUptimeNs: UInt64 = 0) {
        self.gameId = gameId
        self.currentQuestionId = currentQuestionId
        self.currentQuestionIndex = currentQuestionIndex
        self.phase = phase
        self.questionStartSeq = questionStartSeq
        self.questionStartHostUptimeNs = questionStartHostUptimeNs
        self.closeAtHostUptimeNs = closeAtHostUptimeNs
    }
}

// MARK: - Answer (client-created, immutable)

class Answer: Codable, Identifiable {
    @DocumentID var id: String?
    var gameId: String
    var questionId: String
    var playerId: String
    var selectedChoiceIndex: Int
    var clientCreatedAtUptimeNs: UInt64

    init(gameId: String, questionId: String, playerId: String,
         selectedChoiceIndex: Int, clientCreatedAtUptimeNs: UInt64) {
        self.gameId = gameId
        self.questionId = questionId
        self.playerId = playerId
        self.selectedChoiceIndex = selectedChoiceIndex
        self.clientCreatedAtUptimeNs = clientCreatedAtUptimeNs
    }
}

// MARK: - Answer Result (host-created)

class AnswerResult: Codable, Identifiable {
    @DocumentID var id: String?
    var gameId: String
    var questionId: String
    var playerId: String
    var isCorrect: Bool
    var points: Int
    var hostReceivedSeq: Int
    var hostReceivedUptimeNs: UInt64

    init(gameId: String, questionId: String, playerId: String,
         isCorrect: Bool, points: Int, hostReceivedSeq: Int, hostReceivedUptimeNs: UInt64) {
        self.gameId = gameId
        self.questionId = questionId
        self.playerId = playerId
        self.isCorrect = isCorrect
        self.points = points
        self.hostReceivedSeq = hostReceivedSeq
        self.hostReceivedUptimeNs = hostReceivedUptimeNs
    }
}

// MARK: - Score (host-created/updated)

class PlayerScore: Codable, Identifiable {
    @DocumentID var id: String?
    var gameId: String
    var playerId: String
    var displayName: String
    var totalPoints: Int
    var correctCount: Int
    var rank: Int

    init(gameId: String, playerId: String, displayName: String,
         totalPoints: Int = 0, correctCount: Int = 0, rank: Int = 0) {
        self.gameId = gameId
        self.playerId = playerId
        self.displayName = displayName
        self.totalPoints = totalPoints
        self.correctCount = correctCount
        self.rank = rank
    }
}

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable, Codable {
    var id: String { playerId }
    var playerId: String
    var displayName: String
    var totalPoints: Int
    var rank: Int
}

// MARK: - Leaderboard (host-created)

class Leaderboard: Codable {
    @DocumentID var id: String?
    var gameId: String
    var entries: [LeaderboardEntry]

    init(gameId: String, entries: [LeaderboardEntry] = []) {
        self.gameId = gameId
        self.entries = entries
    }
}

// MARK: - Sample Questions

enum SampleQuestions {
    static func generate(gameId: String) -> [Question] {
        let data: [(String, [String], Int)] = [
            ("What is the capital of France?", ["London", "Berlin", "Paris", "Madrid"], 2),
            ("Which planet is closest to the Sun?", ["Venus", "Mercury", "Mars", "Earth"], 1),
            ("What is 7 x 8?", ["54", "56", "58", "64"], 1),
            ("Who painted the Mona Lisa?", ["Picasso", "Van Gogh", "Da Vinci", "Rembrandt"], 2),
            ("What is the chemical symbol for Gold?", ["Go", "Gd", "Au", "Ag"], 2),
            ("Which ocean is the largest?", ["Atlantic", "Indian", "Arctic", "Pacific"], 3),
            ("How many continents are there?", ["5", "6", "7", "8"], 2),
            ("What year did World War II end?", ["1943", "1944", "1945", "1946"], 2),
            ("What is the speed of light in km/s (approx)?", ["200,000", "300,000", "400,000", "500,000"], 1),
            ("Which element has atomic number 1?", ["Helium", "Hydrogen", "Lithium", "Carbon"], 1),
        ]

        return data.enumerated().map { index, q in
            Question(
                gameId: gameId,
                index: index,
                text: q.0,
                choices: q.1,
                correctChoiceIndex: q.2
            )
        }
    }
}
