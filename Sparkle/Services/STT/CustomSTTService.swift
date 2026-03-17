//
//  CustomSTTService.swift
//  Sparkle
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

        // Create multipart form data as a temp file to avoid loading audio into memory
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add API key if provided
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Write multipart body to temp file
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        defer { try? handle.close() }

        // File part header
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        handle.write("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)

        // Stream audio file in chunks
        let audioHandle = try FileHandle(forReadingFrom: audioURL)
        defer { try? audioHandle.close() }
        while autoreleasepool(invoking: {
            let chunk = audioHandle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty { return false }
            handle.write(chunk)
            return true
        }) {}

        handle.write("\r\n".data(using: .utf8)!)

        // Model field (optional, for OpenAI-compatible endpoints)
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        handle.write("whisper-1\r\n".data(using: .utf8)!)

        handle.write("--\(boundary)--\r\n".data(using: .utf8)!)
        try handle.close()

        do {
            let (data, response) = try await URLSession.shared.upload(for: request, fromFile: tempURL)

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
