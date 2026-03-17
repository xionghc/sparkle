//
//  DeepgramService.swift
//  Sparkle
//
//  Deepgram API integration
//

import Foundation

final class DeepgramService: STTServiceProtocol {
    private let apiKey: String
    private let apiURL = "https://api.deepgram.com/v1/listen"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard !apiKey.isEmpty else {
            throw STTError.invalidAPIKey
        }

        guard let url = URL(string: "\(apiURL)?model=nova-2&smart_format=true") else {
            throw STTError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")

        do {
            // Stream file directly instead of loading into memory
            let (data, response) = try await URLSession.shared.upload(for: request, fromFile: audioURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw STTError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJson["err_msg"] as? String {
                    throw STTError.transcriptionFailed(message)
                }
                throw STTError.transcriptionFailed("HTTP \(httpResponse.statusCode)")
            }

            // Parse Deepgram response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [String: Any],
                  let channels = results["channels"] as? [[String: Any]],
                  let firstChannel = channels.first,
                  let alternatives = firstChannel["alternatives"] as? [[String: Any]],
                  let firstAlternative = alternatives.first,
                  let transcript = firstAlternative["transcript"] as? String else {
                throw STTError.invalidResponse
            }

            return transcript

        } catch let error as STTError {
            throw error
        } catch {
            throw STTError.networkError(error)
        }
    }
}
