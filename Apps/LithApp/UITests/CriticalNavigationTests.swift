import XCTest

final class CriticalNavigationTests: XCTestCase {
    @MainActor private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["UI Test Note"].firstMatch.waitForExistence(timeout: 10))
        return app
    }

    @MainActor func testNoteDetailAndEditorNavigation() {
        let app = launchApp()
        defer { app.terminate() }
        activate(app.staticTexts["UI Test Note"].firstMatch)
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        activate(app.buttons["Edit"])
        let body = app.textViews["note-body-editor"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        activate(body)
        body.typeText(" UI edited")
        activate(app.buttons["Done"].firstMatch)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "UI edited")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func testRSSApprovalAndSavedNoteNavigation() {
        let app = launchApp()
        defer { app.terminate() }
        selectSection("RSS Inbox", identifier: "rss", app: app)
        let article = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "UI Test Article")).firstMatch
        XCTAssertTrue(article.waitForExistence(timeout: 5))
        activate(article)
        XCTAssertTrue(app.buttons["Approve"].waitForExistence(timeout: 5))
        activate(app.buttons["Approve"])
        XCTAssertTrue(app.buttons["Save as Note"].waitForExistence(timeout: 5))
        activate(app.buttons["Save as Note"])
        XCTAssertTrue(app.buttons["Open Saved Note"].waitForExistence(timeout: 5))
        activate(app.buttons["Open Saved Note"])
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
    }

    @MainActor func testSearchAndSettingsNavigation() {
        let app = launchApp()
        defer { app.terminate() }
        selectSection("Search & Graph", identifier: "search", app: app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        activate(search)
        search.typeText("Isolated")
        XCTAssertTrue(app.staticTexts["UI Test Note"].firstMatch.waitForExistence(timeout: 5))
        selectSection("Settings", identifier: "settings", app: app)
        XCTAssertTrue(app.staticTexts["Settings"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor private func selectSection(_ title: String, identifier: String, app: XCUIApplication) {
        #if os(iOS)
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        activate(tab)
        #else
        let row = app.descendants(matching: .any)["navigation-\(identifier)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()
        #endif
    }
    @MainActor private func activate(_ element: XCUIElement) {
        #if os(iOS)
        element.tap()
        #else
        element.click()
        #endif
    }

}
