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

    private func editorIsOpen(_ app: XCUIApplication) -> Bool {
        app.descendants(matching: .any)["Insert"].waitForExistence(timeout: 5)
    }

    private func backToLibrary(_ app: XCUIApplication) {
        app.buttons["Presentations"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Presentations"].waitForExistence(timeout: 5), "did not return to library")
    }

    private func openCard(_ app: XCUIApplication, containing text: String) {
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "\(text) card missing")
        card.tap()
        sleep(2)
    }

    func testOpenSampleDeck() {
        let app = XCUIApplication()
        app.launch()
        shot(app, "library")
        openCard(app, containing: "Welcome")
        XCTAssertEqual(app.state, .runningForeground, "app died opening sample deck")
        shot(app, "sample-editor")
        dumpTree(app, "sample-editor")
        XCTAssertTrue(editorIsOpen(app), "sample editor did not open")
        backToLibrary(app)
        openCard(app, containing: "Welcome")
        XCTAssertTrue(editorIsOpen(app), "sample editor did not reopen")
    }

    func testCreateAndOpenNewDeck() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["New Presentation"].tap()
        XCTAssertTrue(app.buttons["Create"].waitForExistence(timeout: 5))
        app.buttons["Create"].tap()
        sleep(2)
        shot(app, "after-create")
        dumpTree(app, "after-create")
        XCTAssertEqual(app.state, .runningForeground, "app died creating deck")
        XCTAssertTrue(editorIsOpen(app), "editor did not open after create")
        backToLibrary(app)
        openCard(app, containing: "Untitled")
        shot(app, "after-card-tap")
        XCTAssertEqual(app.state, .runningForeground, "app died reopening new deck")
        XCTAssertTrue(editorIsOpen(app), "new deck did not reopen")
    }
}
