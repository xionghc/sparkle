//
//  OpenAIWhisperService.swift
//  VBCode
//
//  OpenAI Whisper API integration
//

import Foundation

final class OpenAIWhisperService: STTServiceProtocol {
    private let apiURL: String
    private let apiKey: String

    init(apiURL: String, apiKey: String) {
        self.apiURL = apiURL
        self.apiKey = apiKey
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw STTError.invalidURL
        }

        guard !apiKey.isEmpty else {
            throw STTError.invalidAPIKey
        }

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw STTError.fileReadError
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add response format field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw STTError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw STTError.transcriptionFailed(message)
                }
                throw STTError.transcriptionFailed("HTTP \(httpResponse.statusCode)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                throw STTError.invalidResponse
            }

            return text

        } catch let error as STTError {
            throw error
        } catch {
            throw STTError.networkError(error)
        }
    }
}
