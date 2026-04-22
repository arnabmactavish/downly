import XCTest
@testable import Downly

final class ChunkManagerTests: XCTestCase {

    let manager = ChunkManager()

    // MARK: - Even division

    func testSplitIntoChunks_evenDivision() {
        let chunks = manager.splitIntoChunks(totalSize: 12_000_000, chunkSize: 4_000_000)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].start, 0)
        XCTAssertEqual(chunks[0].end,   3_999_999)
        XCTAssertEqual(chunks[1].start, 4_000_000)
        XCTAssertEqual(chunks[1].end,   7_999_999)
        XCTAssertEqual(chunks[2].start, 8_000_000)
        XCTAssertEqual(chunks[2].end,  11_999_999)
    }

    // MARK: - Uneven division (last chunk smaller)

    func testSplitIntoChunks_unevenDivision() {
        let chunks = manager.splitIntoChunks(totalSize: 10_000_001, chunkSize: 4_000_000)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[2].start, 8_000_000)
        XCTAssertEqual(chunks[2].end,  10_000_000)  // only 1 byte in last chunk
    }

    // MARK: - Single chunk (file smaller than chunk size)

    func testSplitIntoChunks_singleChunk() {
        let chunks = manager.splitIntoChunks(totalSize: 1_000_000, chunkSize: 4_000_000)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].start, 0)
        XCTAssertEqual(chunks[0].end,   999_999)
    }

    // MARK: - Edge cases

    func testSplitIntoChunks_zeroSize_returnsEmpty() {
        let chunks = manager.splitIntoChunks(totalSize: 0, chunkSize: 4_000_000)
        XCTAssertTrue(chunks.isEmpty)
    }

    func testSplitIntoChunks_exactlyOneChunkSize() {
        let chunks = manager.splitIntoChunks(totalSize: 4_000_000, chunkSize: 4_000_000)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].end, 3_999_999)
    }

    // MARK: - Indices are sequential

    func testSplitIntoChunks_indicesAreSequential() {
        let chunks = manager.splitIntoChunks(totalSize: 20_000_000, chunkSize: 4_000_000)
        for (i, chunk) in chunks.enumerated() {
            XCTAssertEqual(chunk.index, i)
        }
    }

    // MARK: - Byte ranges cover the entire file

    func testSplitIntoChunks_rangesCoverFullFile() {
        let totalSize: Int64 = 11_500_000
        let chunks = manager.splitIntoChunks(totalSize: totalSize, chunkSize: 4_000_000)
        XCTAssertEqual(chunks.first?.start, 0)
        XCTAssertEqual(chunks.last?.end, totalSize - 1)
    }

    // MARK: - Range header string

    func testMakeChunkRequest_hasRangeHeader() {
        let url = URL(string: "https://example.com/file.zip")!
        let range: ChunkRange = (index: 0, start: 0, end: 3_999_999)
        let request = manager.makeChunkRequest(url: url, range: range)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=0-3999999")
    }
}
