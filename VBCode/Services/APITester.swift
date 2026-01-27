//
//  APITester.swift
//  VBCode
//
//  API testing utilities for STT and LLM connections
//

import Foundation

struct APITester {

    enum TestError: LocalizedError {
        case invalidURL
        case invalidAPIKey
        case networkError(Error)
        case invalidResponse(Int)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .invalidAPIKey:
                return "Invalid or missing API key"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse(let code):
                return "HTTP error: \(code)"
            case .apiError(let message):
                return message
            }
        }
    }

    /// Test STT API connection
    static func testSTT(provider: STTProvider, apiURL: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TestError.invalidAPIKey
        }

        // Different providers have different test approaches
        switch provider {
        case .openAIWhisper, .custom:
            return try await testOpenAICompatibleSTT(apiURL: apiURL, apiKey: apiKey)
        case .deepgram:
            return try await testDeepgram(apiKey: apiKey)
        case .assemblyAI:
            return try await testAssemblyAI(apiKey: apiKey)
        case .aliyunASR:
            return try await testAliyunASR(apiKey: apiKey)
        case .localWhisper:
            throw TestError.apiError("Local Whisper cannot be tested via API")
        }
    }

    /// Test LLM API connection
    static func testLLM(apiURL: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw TestError.invalidURL
        }

        guard !apiKey.isEmpty else {
            throw TestError.invalidAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Send a simple test message
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Say 'API connection successful' in exactly those words."]
            ],
            "max_tokens": 20
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw TestError.apiError(message)
                }
                throw TestError.invalidResponse(httpResponse.statusCode)
            }

            // Parse response to confirm it worked
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let _ = message["content"] as? String {
                return "Connection successful! Model: \(model)"
            }

            throw TestError.apiError("Invalid response format")

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    // MARK: - Provider-specific Tests

    private static func testOpenAICompatibleSTT(apiURL: String, apiKey: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw TestError.invalidURL
        }

        // For OpenAI-compatible APIs, we'll check if the endpoint is reachable
        // by sending a minimal request (it will fail due to missing file, but we can check auth)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        // Send empty body to check authentication
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            // 400 means the request format was understood but file was missing - API key is valid
            // 401 means unauthorized - API key is invalid
            // 200 would be unexpected without a file
            if httpResponse.statusCode == 401 {
                throw TestError.apiError("Invalid API key")
            }

            if httpResponse.statusCode == 400 {
                // Check if it's complaining about missing file (expected)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    if message.lowercased().contains("file") || message.lowercased().contains("audio") {
                        return "Connection successful! API key verified."
                    }
                    throw TestError.apiError(message)
                }
                return "Connection successful! API key verified."
            }

            if httpResponse.statusCode == 200 {
                return "Connection successful!"
            }

            // Other error codes
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw TestError.apiError(message)
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    private static func testDeepgram(apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.deepgram.com/v1/projects") else {
            throw TestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw TestError.apiError("Invalid API key")
            }

            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let projects = json["projects"] as? [[String: Any]] {
                    return "Connection successful! Found \(projects.count) project(s)."
                }
                return "Connection successful!"
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    private static func testAssemblyAI(apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.assemblyai.com/v2/transcript") else {
            throw TestError.invalidURL
        }

        // List recent transcripts to verify API key
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode == 401 {
                throw TestError.apiError("Invalid API key")
            }

            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let transcripts = json["transcripts"] as? [[String: Any]] {
                    return "Connection successful! Found \(transcripts.count) transcript(s)."
                }
                return "Connection successful!"
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    private static func testAliyunASR(apiKey: String) async throws -> String {
        // Test the DashScope API by checking models endpoint
        guard let url = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/models") else {
            throw TestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode == 401 {
                throw TestError.apiError("Invalid API key")
            }

            if httpResponse.statusCode == 200 {
                return "Connection successful! API key verified."
            }

            // 404 might mean endpoint doesn't exist but key is ok
            if httpResponse.statusCode == 404 {
                // Try another approach - send a minimal request
                return try await testAliyunASRAlternative(apiKey: apiKey)
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw TestError.apiError(message)
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    private static func testAliyunASRAlternative(apiKey: String) async throws -> String {
        // Alternative test using the transcription endpoint
        guard let url = URL(string: "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription") else {
            throw TestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Send minimal body to check auth
        let body: [String: Any] = [
            "model": "paraformer-v2",
            "input": ["file_urls": []]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode == 401 {
                throw TestError.apiError("Invalid API key")
            }

            // 400 with "file_urls" error means auth is ok
            if httpResponse.statusCode == 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    if message.lowercased().contains("file") || message.lowercased().contains("url") || message.lowercased().contains("input") {
                        return "Connection successful! API key verified."
                    }
                }
                return "Connection successful! API key verified."
            }

            if httpResponse.statusCode == 200 {
                return "Connection successful!"
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                throw TestError.apiError(message)
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }
}
