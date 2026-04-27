import Foundation
import CouchbaseLiteSwift
import Combine

final class DatabaseManager {
    static let shared = DatabaseManager()

    private(set) var database: Database!
    private(set) var collection: Collection!

    private init() {}

    func initialize() throws {
        database = try Database(name: "quizblitz")
        collection = try database.defaultCollection()
    }

    func close() {
        try? database?.close()
    }

    // MARK: - Reactive Codable CRUD

    func save<T: AnyObject & Encodable>(_ object: T) throws {
        try collection.save(from: object)
    }

    func get<T: AnyObject & Decodable>(id: String, as type: T.Type) throws -> T? {
        return try collection.document(id: id, as: type)
    }

    func delete<T: AnyObject & Encodable>(_ object: T) throws {
        try collection.delete(for: object)
    }

    func deleteDocument(id: String) throws {
        if let doc = try collection.document(id: id) {
            try collection.delete(document: doc)
        }
    }

    // MARK: - Query helpers

    func queryAll<T: AnyObject & Decodable>(
        _ type: T.Type,
        where clause: String
    ) throws -> [T] {
        let sql = "SELECT META().id, * FROM _ WHERE \(clause)"
        let query = try database.createQuery(sql)
        let results = try query.execute().allResults()
        print("[DB] queryAll<\(T.self)> SQL: \(sql) -> \(results.count) results")

        return results.compactMap { result in
            let fullDict = result.toDictionary()
            print("[DB] queryAll result keys: \(fullDict.keys.sorted())")

            // The * expands under the collection name key (usually "_" for default)
            // META().id is under key "id"
            var dict: [String: Any]
            if let nested = fullDict["_"] as? [String: Any] {
                dict = nested
            } else {
                dict = fullDict
            }

            // Inject document meta ID for @DocumentID
            if let metaId = fullDict["id"] as? String {
                dict["id"] = metaId
                print("[DB] Injected meta id: \(metaId)")
            }

            do {
                let data = try JSONSerialization.data(withJSONObject: dict)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let obj = try decoder.decode(T.self, from: data)
                return obj
            } catch {
                print("[DB] Decode error for \(T.self): \(error)")
                return nil
            }
        }
    }

    func getPlayers(gameId: String) throws -> [Player] {
        return try queryAll(Player.self, where: "gameId = '\(gameId)' AND displayName IS NOT MISSING AND joinedAt IS NOT MISSING")
    }

    func getAnswers(gameId: String, questionId: String) throws -> [Answer] {
        return try queryAll(Answer.self, where: "gameId = '\(gameId)' AND questionId = '\(questionId)' AND selectedChoiceIndex IS NOT MISSING")
    }

    func getQuestions(gameId: String) throws -> [Question] {
        let questions = try queryAll(Question.self, where: "gameId = '\(gameId)' AND text IS NOT MISSING AND choices IS NOT MISSING")
        return questions.sorted { $0.index < $1.index }
    }

    func getQuestionState(gameId: String) throws -> QuestionState? {
        let results = try queryAll(QuestionState.self, where: "gameId = '\(gameId)' AND questionStartSeq IS NOT MISSING")
        return results.first
    }

    func getLeaderboard(gameId: String) throws -> Leaderboard? {
        let results = try queryAll(Leaderboard.self, where: "gameId = '\(gameId)' AND entries IS NOT MISSING")
        return results.first
    }

    // MARK: - Combine Publishers

    func collectionChangePublisher() -> AnyPublisher<CollectionChange, Never> {
        return collection.changePublisher()
    }

    func documentChangePublisher(id: String) -> AnyPublisher<DocumentChange, Never> {
        return collection.documentChangePublisher(for: id)
    }

    // MARK: - Cleanup

    func clearAllData() throws {
        try database.delete()
        try initialize()
    }
}
