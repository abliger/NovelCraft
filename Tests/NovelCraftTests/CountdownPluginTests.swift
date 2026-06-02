import XCTest
@testable import NovelCraft

/// 倒计时引擎单元测试
final class CountdownPluginTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            CountdownEngine.shared.items.removeAll()
            CountdownEngine.shared.saveItems()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            CountdownEngine.shared.items.removeAll()
            CountdownEngine.shared.saveItems()
        }
        try await super.tearDown()
    }

    @MainActor
    func testInitialEmpty() {
        let engine = CountdownEngine.shared
        XCTAssertTrue(engine.items.isEmpty)
        XCTAssertNil(engine.nearestRunning)
        XCTAssertFalse(engine.hasRunning)
        XCTAssertFalse(engine.hasFinished)
    }

    @MainActor
    func testAddAndStart() {
        let engine = CountdownEngine.shared
        let item = engine.add(name: "测试", totalSeconds: 60)
        XCTAssertEqual(item.name, "测试")
        XCTAssertEqual(item.totalSeconds, 60)
        XCTAssertEqual(item.remainingSeconds, 60)
        XCTAssertTrue(item.isRunning)
        XCTAssertEqual(engine.items.count, 1)
        XCTAssertTrue(engine.hasRunning)
    }

    @MainActor
    func testPauseAndResume() {
        let engine = CountdownEngine.shared
        let item = engine.add(name: "测试", totalSeconds: 300)
        XCTAssertTrue(item.isRunning)

        engine.pause(id: item.id)
        XCTAssertTrue(engine.items[0].isPaused)

        engine.resume(id: item.id)
        XCTAssertTrue(engine.items[0].isRunning)
    }

    @MainActor
    func testReset() {
        let engine = CountdownEngine.shared
        let item = engine.add(name: "测试", totalSeconds: 600)
        engine.pause(id: item.id)
        engine.reset(id: item.id)
        XCTAssertTrue(engine.items[0].isIdle)
        XCTAssertEqual(engine.items[0].remainingSeconds, 600)
    }

    @MainActor
    func testDelete() {
        let engine = CountdownEngine.shared
        let item = engine.add(name: "测试", totalSeconds: 60)
        XCTAssertEqual(engine.items.count, 1)
        engine.delete(id: item.id)
        XCTAssertTrue(engine.items.isEmpty)
    }

    @MainActor
    func testMultipleTimers() {
        let engine = CountdownEngine.shared
        let _ = engine.add(name: "A", totalSeconds: 3600)
        let b = engine.add(name: "B", totalSeconds: 60)
        XCTAssertEqual(engine.items.count, 2)
        XCTAssertEqual(engine.nearestRunning?.name, "B")
        engine.pause(id: b.id)
        XCTAssertEqual(engine.nearestRunning?.name, "A")
    }

    @MainActor
    func testDisplayDuration() {
        let day = CountdownItem(name: "天", totalSeconds: 86400)
        XCTAssertEqual(day.displayDuration, "1天0小时")
        let hour = CountdownItem(name: "时", totalSeconds: 3600)
        XCTAssertEqual(hour.displayDuration, "1小时0分")
        let minute = CountdownItem(name: "分", totalSeconds: 60)
        XCTAssertEqual(minute.displayDuration, "1分钟")
    }

    @MainActor
    func testCountdownPluginConformance() {
        let plugin = CountdownPlugin()
        XCTAssertEqual(plugin.id, "com.novelcraft.plugins.countdown")
        XCTAssertEqual(plugin.name, "倒计时")
        XCTAssertTrue(plugin.isEnabled)
    }
}
