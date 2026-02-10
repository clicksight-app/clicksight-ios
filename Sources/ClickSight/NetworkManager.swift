import Foundation

/// Handles all HTTP communication with the ClickSight API
final class NetworkManager {
    
    private let apiKey: String
    private let apiHost: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(apiKey: String, apiHost: String) {
        self.apiKey = apiKey
        self.apiHost = apiHost
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Send Event Batch
    
    /// Send a batch of events to the ClickSight API
    func sendBatch(_ events: [ClickSightEvent], completion: @escaping (Bool) -> Void) {
        let payload = BatchPayload(apiKey: apiKey, batch: events)
        
        post(endpoint: "/api/app-analytics/batch", body: payload) { result in
            switch result {
            case .success:
                completion(true)
            case .failure(let error):
                Logger.log("Failed to send batch: \(error.localizedDescription)", level: .error)
                completion(false)
            }
        }
    }
    
    // MARK: - Identify
    
    /// Send an identify call to link anonymous to known user
    func sendIdentify(
        distinctId: String,
        userId: String,
        traits: [String: AnyCodable],
        completion: @escaping (Bool) -> Void
    ) {
        let payload = IdentifyPayload(
            apiKey: apiKey,
            distinctId: distinctId,
            userId: userId,
            traits: traits
        )
        
        post(endpoint: "/api/app-analytics/identify", body: payload) { result in
            switch result {
            case .success:
                completion(true)
            case .failure(let error):
                Logger.log("Failed to identify: \(error.localizedDescription)", level: .error)
                completion(false)
            }
        }
    }
    
    // MARK: - Feature Flags
    
    /// Fetch feature flag decisions from the API
    func fetchFeatureFlags(
        distinctId: String,
        properties: [String: AnyCodable],
        completion: @escaping (Result<[String: FeatureFlagValue], Error>) -> Void
    ) {
        let payload = DecidePayload(
            apiKey: apiKey,
            distinctId: distinctId,
            properties: properties
        )
        
        post(endpoint: "/api/app-analytics/decide", body: payload) { (result: Result<DecideResponse, Error>) in
            switch result {
            case .success(let response):
                completion(.success(response.featureFlags))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private HTTP Methods
    
    private func post<T: Encodable>(
        endpoint: String,
        body: T,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard let url = URL(string: "\(apiHost)\(endpoint)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("clicksight-ios/\(ClickSight.sdkVersion)", forHTTPHeaderField: "User-Agent")
        
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
                Logger.log("API error \(httpResponse.statusCode): \(body)", level: .error)
                completion(.failure(NetworkError.httpError(httpResponse.statusCode)))
                return
            }
            
            completion(.success(data ?? Data()))
        }
        
        task.resume()
    }
    
    private func post<T: Encodable, R: Decodable>(
        endpoint: String,
        body: T,
        completion: @escaping (Result<R, Error>) -> Void
    ) {
        post(endpoint: endpoint, body: body) { (result: Result<Data, Error>) in
            switch result {
            case .success(let data):
                do {
                    let decoded = try self.decoder.decode(R.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code): return "HTTP error \(code)"
        }
    }
}
