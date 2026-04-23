import Foundation
import SwiftData

/// Validates that the device has sufficient free space before
/// starting a download or merge operation.
struct DiskSpaceChecker {

    /// Returns `true` if free disk space is at least 110% of `requiredBytes`.
    func hasSufficientSpace(forBytes requiredBytes: Int64) -> Bool {
        guard requiredBytes > 0 else { return true }
        let needed = Int64(Double(requiredBytes) * 1.1)
        return freeBytes() >= needed
    }

    /// Returns available free bytes in the app's temp directory volume.
    func freeBytes() -> Int64 {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(
                forPath: tempDir.path
            )
            return (attrs[.systemFreeSize] as? Int64) ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: -

/// Errors that the file assembly engine may throw.
enum FileAssemblyError: Error, LocalizedError {
    case chunkFileMissing(index: Int, path: String, totalChunks: Int)
    case sizeMismatch(expected: Int64, actual: Int64)
    case writeError(Error)

    var errorDescription: String? {
        switch self {
        case .chunkFileMissing(let index, let path, let totalChunks):
            return "Chunk \(index + 1)/\(totalChunks) temp file not found or empty at \(path). "
                + "The file may have been evicted by the system during backgrounding."
        case .sizeMismatch(let expected, let actual):
            return "File integrity check failed — expected \(expected) bytes, got \(actual) bytes"
        case .writeError(let underlying):
            return "Write error: \(underlying.localizedDescription)"
        }
    }
}

// MARK: -

/// Merges downloaded chunk temp files into a single final output file
/// using `FileHandle` streaming to maintain constant memory usage.
struct FileAssemblyEngine {

    private let diskSpaceChecker: DiskSpaceChecker

    init(diskSpaceChecker: DiskSpaceChecker = .init()) {
        self.diskSpaceChecker = diskSpaceChecker
    }

    // MARK: - Public API

    /// Merges `chunks` (sorted by `index`) into `outputURL`.
    ///
    /// - Parameters:
    ///   - chunks:     ``ChunkRecord`` list for the download (any order).
    ///   - outputURL:  Destination for the final assembled file.
    ///   - totalSize:  Expected byte count for post-merge validation.
    func merge(
        chunks: [ChunkRecord],
        into outputURL: URL,
        expectedSize: Int64
    ) async throws {
        // Sort chunks by index
        let sorted = chunks.sorted { $0.index < $1.index }

        // Validate all chunk temp files exist and are non-empty before starting
        for chunk in sorted {
            guard let path = chunk.tempFilePath,
                  FileManager.default.fileExists(atPath: path)
            else {
                throw FileAssemblyError.chunkFileMissing(
                    index: chunk.index,
                    path: chunk.tempFilePath ?? "<nil>",
                    totalChunks: sorted.count
                )
            }
            // Guard against zero-byte chunks — iOS may evict file contents
            // while preserving the directory entry.
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            let fileSize = (attrs?[.size] as? Int64) ?? 0
            if fileSize == 0 {
                throw FileAssemblyError.chunkFileMissing(
                    index: chunk.index,
                    path: path,
                    totalChunks: sorted.count
                )
            }
        }

        // Create / truncate the output file
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        guard let outputHandle = FileHandle(forWritingAtPath: outputURL.path) else {
            throw FileAssemblyError.writeError(
                NSError(domain: "FileAssembly", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot open output file"])
            )
        }
        defer { try? outputHandle.close() }

        // Stream each chunk into the output file
        for chunk in sorted {
            let chunkURL = URL(fileURLWithPath: chunk.tempFilePath!)
            guard let chunkHandle = FileHandle(forReadingAtPath: chunkURL.path) else {
                throw FileAssemblyError.chunkFileMissing(
                    index: chunk.index,
                    path: chunkURL.path,
                    totalChunks: sorted.count
                )
            }
            defer { try? chunkHandle.close() }

            // Read and write in 1 MB blocks to keep heap usage bounded
            let bufferSize = 1_024 * 1_024
            while true {
                guard let data = try chunkHandle.read(upToCount: bufferSize),
                      !data.isEmpty
                else { break }
                do {
                    try outputHandle.write(contentsOf: data)
                } catch {
                    throw FileAssemblyError.writeError(error)
                }
            }
        }

        // Validate final file size
        if expectedSize > 0 {
            let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let actualSize = (attrs[.size] as? Int64) ?? 0
            guard actualSize == expectedSize else {
                try? FileManager.default.removeItem(at: outputURL)
                throw FileAssemblyError.sizeMismatch(
                    expected: expectedSize,
                    actual: actualSize
                )
            }
        }

        // Delete temp files on success
        deleteChunkFiles(for: chunks)
    }

    // MARK: - Cleanup

    /// Deletes all `.partN` temp files for the given chunks.
    func deleteChunkFiles(for chunks: [ChunkRecord]) {
        for chunk in chunks {
            guard let path = chunk.tempFilePath else { continue }
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    /// Scans temp directories for orphaned `.partN` files not belonging to
    /// any active download and deletes them. Called at app launch.
    ///
    /// Scans both the system `tmp/` and the App Group container's `tmp/`
    /// to cover files from both current and legacy storage paths.
    func cleanupOrphanedTempFiles(
        activeDownloadIDs: Set<String>
    ) {
        let fm = FileManager.default
        var dirsToScan: [URL] = [fm.temporaryDirectory]

        // Also scan the App Group container's tmp/ directory
        if let appGroupURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: AppModelContainer.appGroupID
        ) {
            let groupTmp = appGroupURL.appendingPathComponent("tmp", isDirectory: true)
            dirsToScan.append(groupTmp)
        }

        for dir in dirsToScan {
            guard let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            ) else { continue }

            for fileURL in contents {
                let name = fileURL.lastPathComponent
                // Match pattern: <UUID>.partN or <UUID>.tmp
                guard name.contains(".part") || name.hasSuffix(".tmp") else { continue }
                let prefix = String(name.split(separator: ".").first ?? Substring(name))
                if !activeDownloadIDs.contains(prefix) {
                    try? fm.removeItem(at: fileURL)
                }
            }
        }
    }
}
