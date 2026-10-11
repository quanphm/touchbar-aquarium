import Foundation

/// Endpoint, model, and credentials for the System One API.
public struct JevConfig {
    public var endpoint: URL
    public var model: String
    public var apiKey: String
    public var timeout: TimeInterval

    public init(apiKey: String,
                endpoint: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!,
                model: String = "jev-latest",
                timeout: TimeInterval = 6) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
        self.timeout = timeout
    }
}

public enum JevError: Error, LocalizedError {
    case missingKey
    case transport
    case http(status: Int, body: String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .missingKey: return "No TypeSafe API key found"
        case .transport: return "System One request failed before a response"
        case .http(let status, _): return "System One returned HTTP \(status)"
        case .decoding(let m): return "Could not read System One response: \(m)"
        }
    }
}

/// One typed answer. Fields are optional because the shape depends on the
/// question `type` (noul / choice / score).
public struct JevAnswer: Decodable, Equatable {
    public var type: String?
    public var noul: Double?
    public var choice: String?
    public var score: Double?
    public var confidence: Double?
    public var probabilities: [String: Double]?
    public var legend: [String: String]?
}

public struct JevUsage: Decodable, Equatable {
    public var inputTokens: Int?
    public var outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

public struct JevResponse: Equatable {
    public var model: String?
    public var answers: [String: JevAnswer]
    public var usage: JevUsage?
}

// MARK: - Wire types

private struct SystemOneRequest: Encodable {
    let model: String
    let state: JSONValue
    let questions: [String: JSONValue]
}

private struct SystemOneResponse: Decodable {
    let model: String?
    let answers: [String: JevAnswer]
    let usage: JevUsage?
}

/// Small JSON builders for the three question types. `instructions` can carry a
/// backticked path into the state, e.g. `candidates[0]`.
public enum JevQuestion {
    public static func noul(_ instructions: String, yes: String? = nil, no: String? = nil) -> JSONValue {
        var obj: [String: JSONValue] = ["type": .string("noul"), "instructions": .string(instructions)]
        if let yes, let no {
            obj["criteria"] = .object(["true": .string(yes), "false": .string(no)])
        }
        return .object(obj)
    }

    public static func score(_ instructions: String, levels: [String]) -> JSONValue {
        .object([
            "type": .string("score"),
            "instructions": .string(instructions),
            "criteria": .array(levels.map { .string($0) }),
        ])
    }

    public static func choice(_ instructions: String, options: [String: String]) -> JSONValue {
        .object([
            "type": .string("choice"),
            "instructions": .string(instructions),
            "criteria": .object(options.mapValues { .string($0) }),
        ])
    }
}

/// Minimal `URLSession` client for `POST /v1/systemone`. Retries 429/529 with
/// backoff, as the API reference recommends.
public final class JevClient {
    private let config: JevConfig
    private let session: URLSession
    private let maxRetries: Int

    public init(config: JevConfig, session: URLSession = .shared, maxRetries: Int = 2) {
        self.config = config
        self.session = session
        self.maxRetries = maxRetries
    }

    public func evaluate(state: JSONValue, questions: [String: JSONValue]) async throws -> JevResponse {
        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            SystemOneRequest(model: config.model, state: state, questions: questions)
        )

        var attempt = 0
        while true {
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw JevError.transport
            }
            guard let http = response as? HTTPURLResponse else { throw JevError.transport }

            if (http.statusCode == 429 || http.statusCode == 529), attempt < maxRetries {
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(400_000_000) * UInt64(attempt))
                continue
            }
            guard (200..<300).contains(http.statusCode) else {
                throw JevError.http(status: http.statusCode,
                                    body: String(data: data, encoding: .utf8) ?? "")
            }
            do {
                let decoded = try JSONDecoder().decode(SystemOneResponse.self, from: data)
                return JevResponse(model: decoded.model, answers: decoded.answers, usage: decoded.usage)
            } catch {
                throw JevError.decoding(String(describing: error))
            }
        }
    }
}
