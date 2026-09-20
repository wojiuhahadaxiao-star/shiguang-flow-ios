import XCTest
@testable import FlowCore

final class FlowSessionTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private let day = Date(timeIntervalSince1970: 1_700_006_400)
    private func records(_ count: Int) -> [PhotoRecord] {
        let start = calendar.startOfDay(for: day)
        return (0..<count).map { PhotoRecord(id: "p\($0)", date: start.addingTimeInterval(Double($0 * 60))) }
    }
    private func make(_ count: Int = 61) -> FlowSession {
        let session = FlowSession(calendar: calendar); session.update(records(count)); session.setRandomBatch(["p27", "p3", "p50"]); return session
    }
    func testDateEntryStartsOnFocusedPhotosPageAndReturnsToRandomAnchor() {
        let s = make(); XCTAssertEqual(s.toggleMode(focused: "p27"), "p27")
        XCTAssertEqual(s.page, 1); XCTAssertEqual(s.visibleIDs.first, "p25"); XCTAssertEqual(s.visibleIDs.count, 25)
        XCTAssertTrue(s.movePage(1)); XCTAssertEqual(s.visibleIDs.count, 11)
        XCTAssertEqual(s.toggleMode(focused: "p50"), "p27"); XCTAssertEqual(s.visibleIDs, ["p27", "p3", "p50"])
    }
    func testPagingHasNoSkippedOrRepeatedPhotos() {
        let s = make(); s.toggleMode(focused: "p3")
        var collected = s.visibleIDs
        while s.movePage(1) { collected += s.visibleIDs }
        XCTAssertEqual(collected, records(61).map(\.id)); XCTAssertFalse(s.movePage(1))
        XCTAssertTrue(s.movePage(-1)); XCTAssertEqual(s.visibleIDs.first, "p25")
    }
    func testUndoRestoresModePageAndRandomOrderAfterSwitching() {
        let s = make(); s.stage("p27"); XCTAssertEqual(s.pending, ["p27"])
        XCTAssertEqual(s.visibleIDs, ["p3", "p50"])
        s.toggleMode(focused: "p3"); XCTAssertEqual(s.undo(), "p27")
        XCTAssertEqual(s.mode, .random); XCTAssertEqual(s.visibleIDs, ["p27", "p3", "p50"])
    }
    func testDeleteFinalDayPageClampsAndUndoRestoresLastPage() {
        let s = make(26); s.setRandomBatch(["p25"]); s.toggleMode(focused: "p25")
        XCTAssertEqual(s.page, 1); s.stage("p25"); XCTAssertEqual(s.page, 0)
        XCTAssertEqual(s.undo(), "p25"); XCTAssertEqual(s.page, 1); XCTAssertEqual(s.visibleIDs, ["p25"])
    }
    func testMarkDoesNotDeleteAndCommitOnlyRemovesConfirmedIDs() {
        let s = make(); s.stage("p27"); s.stage("p3")
        XCTAssertEqual(s.records.count, 61)
        s.committed(["p27"]); XCTAssertEqual(s.pending, ["p3"]); XCTAssertEqual(s.records.count, 60)
        XCTAssertEqual(s.undo(), "p3"); XCTAssertFalse(s.visibleIDs.contains("p27"))
    }
    func testRestoredPendingMarksCanBeUndoneAfterRelaunch() {
        let s = FlowSession(calendar: calendar, pending: ["p25", "p25"]); s.update(records(26))
        XCTAssertEqual(s.pending.count, 1); XCTAssertEqual(s.undo(), "p25"); XCTAssertEqual(s.page, 1)
        XCTAssertTrue(s.visibleIDs.contains("p25"))
    }
    func testRestrictedLibraryRefreshRemovesUnavailableReferences() {
        let s = make(); s.stage("p27"); s.update([PhotoRecord(id: "p3", date: day)])
        XCTAssertTrue(s.pending.isEmpty); XCTAssertEqual(s.visibleIDs, ["p3"]); XCTAssertFalse(s.canUndo)
    }
    func testUndatedPhotoCannotEnterDayButCanBeRestored() {
        let s = FlowSession(calendar: calendar); s.update([PhotoRecord(id: "undated", date: nil)])
        XCTAssertNil(s.toggleMode(focused: "undated")); XCTAssertEqual(s.mode, .random)
        s.stage("undated"); XCTAssertTrue(s.visibleIDs.isEmpty); XCTAssertEqual(s.undo(), "undated")
    }
    func testEmptyLibraryAndRepeatedMarksAreSafe() {
        let s = FlowSession(calendar: calendar); s.update([]); XCTAssertTrue(s.visibleIDs.isEmpty)
        XCTAssertFalse(s.movePage(1)); XCTAssertNil(s.undo())
        s.update(records(1)); s.stage("p0"); s.stage("p0"); XCTAssertEqual(s.pending, ["p0"])
        s.restoreAll(); XCTAssertTrue(s.pending.isEmpty); XCTAssertEqual(s.visibleIDs, ["p0"])
    }
    func testDayUsesCalendarBoundary() {
        let s = FlowSession(calendar: calendar)
        let start = calendar.startOfDay(for: day)
        s.update([PhotoRecord(id: "before", date: start.addingTimeInterval(-1)), PhotoRecord(id: "inside", date: start), PhotoRecord(id: "after", date: start.addingTimeInterval(86400))])
        s.setRandomBatch(["inside"]); s.toggleMode(focused: "inside"); XCTAssertEqual(s.visibleIDs, ["inside"])
    }
}
