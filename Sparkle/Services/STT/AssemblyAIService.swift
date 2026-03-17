//
//  AssemblyAIService.swift
//  Sparkle
//
//  AssemblyAI API integration
//

import Foundation

final class AssemblyAIService: STTServiceProtocol {
    private let apiKey: String
    private let uploadURL = "https://api.assemblyai.com/v2/upload"
    private let transcriptURL = "https://api.assemblyai.com/v2/transcript"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard !apiKey.isEmpty else {
            throw STTError.invalidAPIKey
        }

        // Step 1: Upload the audio file
        let uploadedURL = try await uploadAudio(audioURL: audioURL)

        // Step 2: Create transcription request
        let transcriptID = try await createTranscript(audioURL: uploadedURL)

        // Step 3: Poll for completion
        return try await pollForResult(transcriptID: transcriptID)
    }

    private func uploadAudio(audioURL: URL) async throws -> String {
        guard let url = URL(string: uploadURL) else {
            throw STTError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        // Stream file directly instead of loading into memory
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: audioURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw STTError.transcriptionFailed("Failed to upload audio")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uploadURL = json["upload_url"] as? String else {
            throw STTError.invalidResponse
        }

        return uploadURL
    }

    private func createTranscript(audioURL: String) async throws -> String {
        guard let url = URL(string: transcriptURL) else {
            throw STTError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["audio_url": audioURL]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw STTError.transcriptionFailed("Failed to create transcript")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let transcriptID = json["id"] as? String else {
            throw STTError.invalidResponse
        }

        return transcriptID
    }

    private func pollForResult(transcriptID: String) async throws -> String {
        guard let url = URL(string: "\(transcriptURL)/\(transcriptID)") else {
            throw STTError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let maxAttempts = 60  // 60 seconds timeout
        var attempts = 0

        while attempts < maxAttempts {
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                throw STTError.invalidResponse
            }

            switch status {
            case "completed":
                guard let text = json["text"] as? String else {
                    throw STTError.invalidResponse
                }
                return text
            case "error":
                let error = json["error"] as? String ?? "Unknown error"
                throw STTError.transcriptionFailed(error)
            default:
                // Still processing, wait and retry
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                attempts += 1
            }
        }

        throw STTError.transcriptionFailed("Transcription timed out")
    }
}
