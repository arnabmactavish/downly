import XCTest
import SwiftData
@testable import Downly

/// Integration tests for ``FileAssemblyEngine``.
///
/// Builds synthetic chunk temp files from known byte patterns and verifies
/// that the merged output is byte-for-byte correct.
final class FileAssemblyEngineTests: XCTestCase {

    var engine: FileAssemblyEngine!
    var tempDir: URL!

    override func setUpWithError() throws {
        engine  = FileAssemblyEngine()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileAssemblyTests/\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helpers

    /// Creates a synthetic ChunkRecord backed by a real temp file.
    @MainActor
    private func makeChunk(
        context: ModelContext,
        index: Int,
        content: Data
    ) throws -> ChunkRecord {
        let path = tempDir
            .appendingPathComponent("test.part\(index)")
            .path
        FileManager.default.createFile(atPath: path, contents: content)

        let chunk = ChunkRecord(
            index: index,
            rangeStart: 0,
            rangeEnd: Int64(content.count) - 1
        )
        chunk.status       = .completed
        chunk.tempFilePath = path
        context.insert(chunk)
        return chunk
    }

    // MARK: - Successful merge

    @MainActor
    func testMerge_threeChunks_producesCorrectOutput() async throws {
        let container = try ModelContainer(
            for: Schema([DownloadItem.self, ChunkRecord.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let part0 = Data([0x00, 0x01, 0x02])
        let part1 = Data([0x03, 0x04, 0x05])
        let part2 = Data([0x06, 0x07])

        let chunk0 = try makeChunk(context: context, index: 0, content: part0)
        let chunk1 = try makeChunk(context: context, index: 1, content: part1)
        let chunk2 = try makeChunk(context: context, index: 2, content: part2)

        let outputURL = tempDir.appendingPathComponent("merged.bin")

        try await engine.merge(
            chunks: [chunk2, chunk0, chunk1], // deliberately unsorted to test sorting
            into: outputURL,
            expectedSize: 8
        )

        let result = try Data(contentsOf: outputURL)
        XCTAssertEqual(result, Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]))
    }

    // MARK: - Missing chunk file

    @MainActor
    func testMerge_missingChunkFile_throwsError() async throws {
        let container = try ModelContainer(
            for: Schema([DownloadItem.self, ChunkRecord.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let chunk = ChunkRecord(index: 0, rangeStart: 0, rangeEnd: 99)
        chunk.status       = .completed
        chunk.tempFilePath = tempDir.appendingPathComponent("nonexistent.part0").path
        context.insert(chunk)

        let outputURL = tempDir.appendingPathComponent("output.bin")

        await XCTAssertThrowsErrorAsync(
            try await engine.merge(chunks: [chunk], into: outputURL, expectedSize: 100)
        ) { error in
            guard case FileAssemblyError.chunkFileMissing = error else {
                XCTFail("Expected chunkFileMissing error")
                return
            }
        }
    }

    // MARK: - Size mismatch

    @MainActor
    func testMerge_sizeMismatch_throwsAndCleansUp() async throws {
        let container = try ModelContainer(
            for: Schema([DownloadItem.self, ChunkRecord.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let chunk = try makeChunk(context: context, index: 0, content: Data([0x00, 0x01]))
        let outputURL = tempDir.appendingPathComponent("output2.bin")

        await XCTAssertThrowsErrorAsync(
            try await engine.merge(chunks: [chunk], into: outputURL, expectedSize: 999)
        ) { error in
            guard case FileAssemblyError.sizeMismatch = error else {
                XCTFail("Expected sizeMismatch error")
                return
            }
        }
        // Output file should have been deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }
}

// MARK: - Async assertion helper

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error but got success \(message)", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
