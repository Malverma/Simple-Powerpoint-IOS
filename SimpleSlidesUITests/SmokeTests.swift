import XCTest

final class SmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func dumpTree(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(string: app.debugDescription)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        print("=== TREE \(name) ===\n\(app.debugDescription)")
    }

    func testOpenSampleDeck() {
        let app = XCUIApplication()
        app.launch()
        sleep(2)
        shot(app, "library")
        dumpTree(app, "library")
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Welcome'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "sample card missing")
        card.tap()
        sleep(3)
        print("=== STATE after sample tap: \(app.state.rawValue)")
        XCTAssertEqual(app.state, .runningForeground, "app died opening sample deck")
        shot(app, "sample-editor")
        dumpTree(app, "sample-editor")
    }

    func testCreateAndOpenNewDeck() {
        let app = XCUIApplication()
        app.launch()
        sleep(2)
        app.buttons["New Presentation"].tap()
        sleep(1)
        shot(app, "new-sheet")
        app.buttons["Create"].tap()
        sleep(3)
        print("=== STATE after create: \(app.state.rawValue)")
        shot(app, "after-create")
        dumpTree(app, "after-create")
        if app.state == .runningForeground, !app.buttons["Insert"].exists {
            let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Untitled'")).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 5), "new card missing")
            card.tap()
            sleep(3)
            print("=== STATE after new card tap: \(app.state.rawValue)")
            shot(app, "after-card-tap")
            dumpTree(app, "after-card-tap")
        }
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.buttons["Insert"].exists, "editor did not open")
    }
}
