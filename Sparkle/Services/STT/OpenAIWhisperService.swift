//
//  OpenAIWhisperService.swift
//  Sparkle
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

        // Create multipart form data as a temp file to avoid loading audio into memory
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        // Model field
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        handle.write("whisper-1\r\n".data(using: .utf8)!)

        // Response format field
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        handle.write("json\r\n".data(using: .utf8)!)

        handle.write("--\(boundary)--\r\n".data(using: .utf8)!)
        try handle.close()

        do {
            let (data, response) = try await URLSession.shared.upload(for: request, fromFile: tempURL)

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
