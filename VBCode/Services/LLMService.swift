//
//  LLMService.swift
//  VBCode
//
//  LLM API integration for text polishing
//

import Foundation

final class LLMService {
    private let settings: AppSettings

    init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    func polish(transcript: String) async throws -> String {
        guard let url = URL(string: settings.llmAPIURL) else {
            throw LLMError.invalidURL
        }

        guard !settings.llmAPIKey.isEmpty else {
            throw LLMError.invalidAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.llmAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": settings.llmModel,
            "messages": [
                ["role": "system", "content": settings.transcriptionPrompt],
                ["role": "user", "content": transcript]
            ],
            "temperature": 0.3,
            "max_tokens": 4096
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw LLMError.polishingFailed(message)
                }
                throw LLMError.polishingFailed("HTTP \(httpResponse.statusCode)")
            }

            // Parse OpenAI-compatible response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw LLMError.invalidResponse
            }

            return content.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }
}

enum LLMError: LocalizedError {
    case invalidURL
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case polishingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid LLM API URL configured"
        case .invalidAPIKey:
            return "Invalid or missing LLM API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from LLM service"
        case .polishingFailed(let message):
            return "Text polishing failed: \(message)"
        }
    }
}
