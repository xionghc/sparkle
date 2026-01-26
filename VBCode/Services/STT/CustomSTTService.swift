//
//  CustomSTTService.swift
//  VBCode
//
//  Custom API endpoint integration for STT
//

import Foundation

final class CustomSTTService: STTServiceProtocol {
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

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw STTError.fileReadError
        }

        // Create multipart form data (OpenAI-compatible format)
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add API key if provided
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model field (optional, for OpenAI-compatible endpoints)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw STTError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                // Try to parse error message
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = errorJson["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        throw STTError.transcriptionFailed(message)
                    } else if let message = errorJson["error"] as? String {
                        throw STTError.transcriptionFailed(message)
                    } else if let message = errorJson["message"] as? String {
                        throw STTError.transcriptionFailed(message)
                    }
                }
                throw STTError.transcriptionFailed("HTTP \(httpResponse.statusCode)")
            }

            // Try to parse response - support multiple formats
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // OpenAI format
                if let text = json["text"] as? String {
                    return text
                }
                // Alternative formats
                if let transcript = json["transcript"] as? String {
                    return transcript
                }
                if let result = json["result"] as? String {
                    return result
                }
            }

            // Try plain text response
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                return text
            }

            throw STTError.invalidResponse

        } catch let error as STTError {
            throw error
        } catch {
            throw STTError.networkError(error)
        }
    }
}
