import Foundation

// MARK: - Supporting types

/// Result of a HEAD request used to decide whether to chunk a download.
struct ServerCapability: Sendable {
    let supportsRanges: Bool
    let contentLength: Int64?
    let suggestedFileName: String?
    let contentType: String?   // e.g. "application/zip", used to infer extension
}

/// A single byte-range to download as one chunk.
typealias ChunkRange = (index: Int, start: Int64, end: Int64)

// MARK: -

/// Analyses a server's capabilities and computes byte-range chunk splits.
struct ChunkManager {

    /// Dedicated ephemeral session for probe requests, kept separate from
    /// the background URLSession in DownloadEngine to avoid connection conflicts.
    private let probeSession: URLSession = URLSession(configuration: .ephemeral)

    // MARK: - Server analysis

    /// Sends a HEAD request and determines whether the server supports
    /// byte-range requests and what the total file size is.
    func analyzeServer(url: URL) async throws -> ServerCapability {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15

        let (_, response) = try await probeSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return ServerCapability(
                supportsRanges: false,
                contentLength: nil,
                suggestedFileName: nil,
                contentType: nil
            )
        }

        let acceptRanges  = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")
        let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length")
            .flatMap { Int64($0) }
        let disposition   = httpResponse.value(forHTTPHeaderField: "Content-Disposition")
        let contentType   = httpResponse.value(forHTTPHeaderField: "Content-Type")

        // Parse suggested filename from Content-Disposition.
        // Supports both `filename="foo.zip"` and RFC 5987 `filename*=UTF-8''foo.zip`.
        var suggestedName: String?
        if let disp = disposition {
            suggestedName = Self.parseFileName(from: disp)
        }

        let supportsRanges = (acceptRanges?.lowercased() == "bytes") && (contentLength != nil)

        return ServerCapability(
            supportsRanges: supportsRanges,
            contentLength: contentLength,
            suggestedFileName: suggestedName,
            contentType: contentType
        )
    }

    // MARK: - Chunk splitting

    /// Splits a file of `totalSize` bytes into chunks of at most `chunkSize` bytes.
    ///
    /// - Returns: An array of ``ChunkRange`` values sorted by index.
    func splitIntoChunks(totalSize: Int64, chunkSize: Int) -> [ChunkRange] {
        guard totalSize > 0, chunkSize > 0 else { return [] }

        let chunkBytes = Int64(chunkSize)
        let chunkCount = Int((totalSize + chunkBytes - 1) / chunkBytes) // ceiling division

        return (0..<chunkCount).map { index in
            let start = Int64(index) * chunkBytes
            let end   = min(start + chunkBytes - 1, totalSize - 1)
            return (index: index, start: start, end: end)
        }
    }

    // MARK: - Request builder

    /// Creates a URLRequest with the appropriate `Range` header for a chunk.
    func makeChunkRequest(url: URL, range: ChunkRange) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("bytes=\(range.start)-\(range.end)", forHTTPHeaderField: "Range")
        return request
    }

    // MARK: - Helpers

    /// Parses the filename from a Content-Disposition header value.
    /// Handles both the plain `filename="foo.zip"` form and the
    /// RFC 5987 `filename*=UTF-8''foo%20bar.zip` extended form.
    private static func parseFileName(from contentDisposition: String) -> String? {
        let components = contentDisposition.components(separatedBy: ";")

        // RFC 5987 extended param wins if present  (filename*=UTF-8''...)
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("filename*=") {
                let value = String(trimmed.dropFirst("filename*=".count))
                // Format: charset'language'percent-encoded-name
                let parts = value.components(separatedBy: "'")
                if parts.count >= 3 {
                    let encoded = parts[2]
                    if let decoded = encoded.removingPercentEncoding, !decoded.isEmpty {
                        return decoded
                    }
                }
            }
        }

        // Plain filename= fallback
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("filename=") {
                let raw = String(trimmed.dropFirst("filename=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !raw.isEmpty { return raw }
            }
        }
        return nil
    }

    // MARK: - Extension inference

    /// Returns a file-extension string (without leading dot) inferred from a
    /// MIME Content-Type value, or `nil` if the type is unrecognised.
    static func inferExtension(from mimeType: String) -> String? {
        // Strip parameters like `;charset=utf-8`
        let base = (mimeType.components(separatedBy: ";").first ?? mimeType)
            .trimmingCharacters(in: .whitespaces).lowercased()
        let table: [String: String] = [
            "application/zip":              "zip",
            "application/x-zip-compressed": "zip",
            "application/x-rar-compressed": "rar",
            "application/x-7z-compressed":  "7z",
            "application/pdf":              "pdf",
            "application/octet-stream":     "",   // too generic, skip
            "video/mp4":                    "mp4",
            "video/x-matroska":             "mkv",
            "video/x-msvideo":              "avi",
            "video/quicktime":              "mov",
            "audio/mpeg":                   "mp3",
            "audio/mp4":                    "m4a",
            "image/jpeg":                   "jpg",
            "image/png":                    "png",
            "text/plain":                   "txt",
        ]
        if let ext = table[base], !ext.isEmpty { return ext }
        return nil
    }
}
