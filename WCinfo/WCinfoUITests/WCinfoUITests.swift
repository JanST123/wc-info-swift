//
//  WCinfoUITests.swift
//  WCinfoUITests
//
//  Created by Jan on 01.10.26.
//

import XCTest

final class WCinfoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private var outputDirectory: String {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let deviceFolder = isIPad ? "iPad_13" : "iPhone_6.9"
        return "/Users/jan/dev/wc-info-swift/WCinfo/AppStoreScreenshots/\(deviceFolder)"
    }

    private func saveScreenshot(_ screenshot: XCUIScreenshot, name: String, language: String) {
        let folder = "\(outputDirectory)/\(language)"
        let fileURL = URL(fileURLWithPath: "\(folder)/\(name).png")
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = screenshot.pngRepresentation
        try? data.write(to: fileURL)
        print("[Screenshot] Successfully saved: \(fileURL.path)")
    }

    @MainActor
    func testCaptureGermanScreenshots() throws {
        try captureAllScreens(language: "de", locale: "de_DE")
    }

    @MainActor
    func testCaptureEnglishScreenshots() throws {
        try captureAllScreens(language: "en", locale: "en_US")
    }

    @MainActor
    private func captureAllScreens(language: String, locale: String) throws {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        if isIPad {
            XCUIDevice.shared.orientation = .landscapeLeft
            Thread.sleep(forTimeInterval: 1.0)
        }

        let app = XCUIApplication()
        app.launchArguments = [
            "-UITest",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()

        // 1. Homescreen
        Thread.sleep(forTimeInterval: 2.0)
        saveScreenshot(XCUIScreen.main.screenshot(), name: "01_Homescreen", language: language)

        // 2. Search for "Berlin" and use the first suggested place
        let searchField = app.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 6.0), "Search field must exist")
        searchField.tap()
        Thread.sleep(forTimeInterval: 0.5)
        searchField.typeText("Berlin")

        // Wait for autocomplete predictions to appear
        let suggestionPredicate = NSPredicate(format: "label CONTAINS[c] 'Berlin'")
        let suggestionButton = app.scrollViews.descendants(matching: .button).matching(suggestionPredicate).firstMatch
        if suggestionButton.waitForExistence(timeout: 8.0) {
            suggestionButton.tap()
        } else {
            let firstButton = app.scrollViews.descendants(matching: .button).firstMatch
            if firstButton.waitForExistence(timeout: 4.0) {
                firstButton.tap()
            }
        }

        // 2. Result Screen
        let navBar = app.navigationBars.firstMatch
        _ = navBar.waitForExistence(timeout: 10.0)
        // Wait for map and toilets list to load
        Thread.sleep(forTimeInterval: 4.0)
        saveScreenshot(XCUIScreen.main.screenshot(), name: "02_ResultScreen", language: language)

        // 5. Open filter settings
        let filterButton = app.buttons["FilterToggleButton"].exists ? app.buttons["FilterToggleButton"] : app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'filter' OR label CONTAINS[c] 'Filter'")).firstMatch
        if filterButton.waitForExistence(timeout: 4.0) {
            filterButton.tap()
            Thread.sleep(forTimeInterval: 1.5)
            saveScreenshot(XCUIScreen.main.screenshot(), name: "05_FilterSettings", language: language)
            // Collapse filter settings back
            filterButton.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }

        // Tap the first toilet cell to reveal action buttons
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5.0) {
            firstCell.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // 4. Detail View of a toilet
        let detailButtonPredicate = NSPredicate(format: "label CONTAINS[c] 'Details' OR label CONTAINS[c] 'details'")
        let detailButton = app.buttons.matching(detailButtonPredicate).firstMatch
        if detailButton.waitForExistence(timeout: 4.0) {
            detailButton.tap()
            Thread.sleep(forTimeInterval: 2.5)
            saveScreenshot(XCUIScreen.main.screenshot(), name: "04_DetailView", language: language)

            // Close detail sheet
            let closeDetail = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'schließen' OR label CONTAINS[c] 'close' OR label CONTAINS[c] 'Fertig' OR label CONTAINS[c] 'Done'")).firstMatch
            if closeDetail.exists {
                closeDetail.tap()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
            }
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Re-tap cell if needed
        if !app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Navigieren' OR label CONTAINS[c] 'Navigate'")).firstMatch.exists {
            let cell = app.cells.firstMatch
            if cell.exists { cell.tap(); Thread.sleep(forTimeInterval: 0.8) }
        }

        // 3. Compass navigation to the first toilet
        let navigateButtonPredicate = NSPredicate(format: "label CONTAINS[c] 'Navigieren' OR label CONTAINS[c] 'Navigate'")
        let navigateButton = app.buttons.matching(navigateButtonPredicate).firstMatch
        if navigateButton.waitForExistence(timeout: 4.0) {
            navigateButton.tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Select "Kompass" / "Compass" in dialog
            let compassOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Kompass' OR label CONTAINS[c] 'Compass'")).firstMatch
            if compassOption.waitForExistence(timeout: 3.0) {
                compassOption.tap()
                Thread.sleep(forTimeInterval: 2.5)
                saveScreenshot(XCUIScreen.main.screenshot(), name: "03_CompassNavigation", language: language)

                // Close compass sheet
                let closeCompass = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'schließen' OR label CONTAINS[c] 'close' OR label CONTAINS[c] 'Fertig' OR label CONTAINS[c] 'Done'")).firstMatch
                if closeCompass.exists {
                    closeCompass.tap()
                } else {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
                }
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // 6. Widget on the home screen
        captureWidgetOnHomeScreen(language: language)
    }

    @MainActor
    private func captureWidgetOnHomeScreen(language: String) {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2.0)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        Thread.sleep(forTimeInterval: 1.0)

        // Enter jiggle mode to show widgets or add widget if not already added
        let homeScreenCenter = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        homeScreenCenter.press(forDuration: 2.0)
        Thread.sleep(forTimeInterval: 1.0)

        // Try to tap Add Widget button (+)
        let addWidgetButton = springboard.buttons["AddWidgetButton"].exists ? springboard.buttons["AddWidgetButton"] : springboard.navigationBars.buttons.firstMatch
        if addWidgetButton.exists {
            addWidgetButton.tap()
            Thread.sleep(forTimeInterval: 1.5)

            let searchField = springboard.searchFields.firstMatch
            if searchField.exists {
                searchField.tap()
                searchField.typeText("WC")
                Thread.sleep(forTimeInterval: 1.0)
            }

            let wcInfoItem = springboard.tables.cells.matching(NSPredicate(format: "label CONTAINS[c] 'WC'")).firstMatch
            if wcInfoItem.exists {
                wcInfoItem.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }

            let addWidgetAction = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Widget' OR label CONTAINS[c] 'hinzufügen' OR label CONTAINS[c] 'Add'")).firstMatch
            if addWidgetAction.exists {
                addWidgetAction.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }

            // Exit jiggle mode
            let doneButton = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Fertig' OR label CONTAINS[c] 'Done' OR identifier == 'done-button'")).firstMatch
            if doneButton.exists {
                doneButton.tap()
            } else {
                springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
            }
            Thread.sleep(forTimeInterval: 1.5)
        } else {
            // If already added, exit jiggle mode
            let doneButton = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Fertig' OR label CONTAINS[c] 'Done' OR identifier == 'done-button'")).firstMatch
            if doneButton.exists {
                doneButton.tap()
            } else {
                springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
            }
            Thread.sleep(forTimeInterval: 1.0)
        }

        saveScreenshot(XCUIScreen.main.screenshot(), name: "06_WidgetHomeScreen", language: language)
    }
}
