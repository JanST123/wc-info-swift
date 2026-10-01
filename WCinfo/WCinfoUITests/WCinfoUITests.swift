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

        let image = screenshot.image
        // Force redraw through UIGraphicsImageRenderer to bake in UIImage.imageOrientation
        // so that iPad landscape screenshots are saved with native 2752x2064 dimensions.
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        if let data = normalizedImage.pngData() {
            try? data.write(to: fileURL)
            print("[Screenshot] Successfully saved: \(fileURL.path) [\(Int(normalizedImage.size.width * normalizedImage.scale))x\(Int(normalizedImage.size.height * normalizedImage.scale))]")
        }
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

        // Enter jiggle/edit mode
        let homeScreenEmptySpace = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        homeScreenEmptySpace.press(forDuration: 2.5)
        Thread.sleep(forTimeInterval: 1.0)

        // In iOS 18+, tap "Edit" / "Bearbeiten" on top left if it exists
        let editMenuButton = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Bearbeiten' OR label CONTAINS[c] 'Edit' OR identifier == 'edit-button'")).firstMatch
        if editMenuButton.waitForExistence(timeout: 2.0) {
            editMenuButton.tap()
            Thread.sleep(forTimeInterval: 1.0)

            let addWidgetMenuItem = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Widget' OR label CONTAINS[c] 'Hinzufügen' OR label CONTAINS[c] 'Add'")).firstMatch
            if addWidgetMenuItem.waitForExistence(timeout: 2.0) {
                addWidgetMenuItem.tap()
                Thread.sleep(forTimeInterval: 1.5)
            }
        } else {
            // Direct Add Widget (+) button
            let addWidgetBtn = springboard.buttons["AddWidgetButton"].exists ? springboard.buttons["AddWidgetButton"] : springboard.navigationBars.buttons.firstMatch
            if addWidgetBtn.exists {
                addWidgetBtn.tap()
                Thread.sleep(forTimeInterval: 1.5)
            }
        }

        // In Widget Gallery Sheet, search for WC
        let searchField = springboard.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3.0) {
            searchField.tap()
            searchField.typeText("WC")
            Thread.sleep(forTimeInterval: 1.0)

            let wcInfoItem = springboard.tables.cells.matching(NSPredicate(format: "label CONTAINS[c] 'WC'")).firstMatch
            if wcInfoItem.waitForExistence(timeout: 2.0) {
                wcInfoItem.tap()
                Thread.sleep(forTimeInterval: 1.0)
            } else {
                let cell = springboard.cells.matching(NSPredicate(format: "label CONTAINS[c] 'WC'")).firstMatch
                if cell.waitForExistence(timeout: 2.0) {
                    cell.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }

            let addWidgetAction = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Widget' OR label CONTAINS[c] 'hinzufügen' OR label CONTAINS[c] 'Add'")).firstMatch
            if addWidgetAction.waitForExistence(timeout: 2.0) {
                addWidgetAction.tap()
                Thread.sleep(forTimeInterval: 1.5)
            }
        }

        // Exit edit mode
        let doneButton = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Fertig' OR label CONTAINS[c] 'Done' OR identifier == 'done-button'")).firstMatch
        if doneButton.exists {
            doneButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
        } else {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        saveScreenshot(XCUIScreen.main.screenshot(), name: "06_WidgetHomeScreen", language: language)
    }
}
