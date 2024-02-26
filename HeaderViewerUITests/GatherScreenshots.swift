//
//  GatherScreenshots.swift
//  HeaderViewerUITests
//
//  Created by Leptos on 2/25/24.
//

import XCTest

// based on https://github.com/leptos-null/PrayerTimes/blob/main/PrayerTimesUITests/GatherScreenshots.swift

final class GatherScreenshots: XCTestCase {
    private var directory: URL?
    private var paths: [String: String] = [:] // file name, description
    
    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        let file = URL(fileURLWithPath: #file)
        let project = URL(fileURLWithPath: "..", isDirectory: true, relativeTo: file)
        
#if os(macOS)
        let model = "macOS"
#else
        let environment = ProcessInfo.processInfo.environment
        guard let model = environment["SIMULATOR_MODEL_IDENTIFIER"] else {
            fatalError("Screenshot collection should be run in the simulator")
        }
#endif
        
        let directory = project
            .appendingPathComponent("docs")
            .appendingPathComponent("Screenshots")
            .appendingPathComponent(model)
        
        let fileManager: FileManager = .default
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            assert(isDirectory.boolValue, "\(directory.path) should be a directory")
        } else {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.directory = directory
    }
    
    override func tearDownWithError() throws {
        var readMe: String = ""
        
#if os(macOS)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        readMe += "## macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)\n\n"
#else
        let environment = ProcessInfo.processInfo.environment
        guard let deviceName = environment["SIMULATOR_DEVICE_NAME"] else {
            fatalError("SIMULATOR_DEVICE_NAME is not set")
        }
        guard let version = environment["SIMULATOR_RUNTIME_VERSION"] else {
            fatalError("SIMULATOR_RUNTIME_VERSION is not set")
        }
        readMe += "## \(deviceName) \(version)\n\n"
#endif
        
        paths
            .sorted { lhs, rhs in
                lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }
            .forEach { pair in
                readMe += "![\(pair.value)](\(pair.key))\n\n"
            }
        
        guard let directory else {
            fatalError("directory is unset")
        }
        
        let fileName = directory.appendingPathComponent("README.md")
        try readMe.write(to: fileName, atomically: true, encoding: .ascii)
    }
    
    private func write(screenshot: XCUIScreenshot, name: String, description: String) throws {
        guard let directory = directory else {
            fatalError("directory is unset")
        }
        
        let path = directory.appendingPathComponent(name).appendingPathExtension("png")
        try screenshot.pngRepresentation.write(to: path, options: .atomic)
        paths[path.lastPathComponent] = description
    }
    
    /*
     influenced by https://github.com/jessesquires/Nine41
     
     $ xcrun simctl list | grep Booted # find booted devices
     run the following for the device you'll be gathering screenshots on:
     
     xcrun simctl status_bar <device> override \
     --time "2021-09-14T16:41:00Z" \
     --dataNetwork "wifi" --wifiMode "active" --wifiBars 3 \
     --cellularMode active --cellularBars 4 --operatorName " " \
     --batteryState charged --batteryLevel 100
     */
    private func statusBarOverrideCommand() -> String {
        let environment = ProcessInfo.processInfo.environment
        guard let deviceUDID = environment["SIMULATOR_UDID"] else {
            fatalError("SIMULATOR_UDID is not set")
        }
        return
"""
xcrun simctl status_bar \(deviceUDID) override \
--time "2021-09-14T16:41:00Z" \
--dataNetwork "wifi" --wifiMode "active" --wifiBars 3 \
--cellularMode active --cellularBars 4 --operatorName " " \
--batteryState charged --batteryLevel 100
"""
    }
    
    func testGetScreenshots() throws {
#if !SCREENSHOT_MODE
        XCTAssert(false, "SCREENSHOT_MODE should be set to gather screenshot")
#endif
        let app = XCUIApplication()
        app.launch()
        
        sleep(1) // window isn't available immediately, seemingly
        let window: XCUIElement = app.windows.firstMatch
        
        try write(screenshot: window.screenshot(), name: "0_landing", description: "Class list")
        
        window.staticTexts["NSProxy"].tap()
        sleep(1) // still animating on compact horizontal size classes
        try write(screenshot: window.screenshot(), name: "1_class_view", description: "Class header")
        
#if os(iOS) || os(visionOS)
        if window.horizontalSizeClass == .compact {
            window.navigationBars.buttons["Header Viewer"].tap()
        }
#endif
        
        let searchField = window.navigationBars.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("NSObject\n")
        sleep(1) // wait for the keyboard to go away
        try write(screenshot: window.screenshot(), name: "2_search_results", description: "Search")
        
        window.navigationBars.buttons["Cancel"].tap()
        
        window.navigationBars.buttons["System Images"].tap()
        
        window.staticTexts["System"].tap()
        window.staticTexts["Library"].tap()
        window.staticTexts["Frameworks"].tap()
        
        try write(screenshot: window.screenshot(), name: "3_directory_list", description: "System image browser")
        
        window.staticTexts["CoreFoundation.framework"].tap()
        window.staticTexts["CoreFoundation"].tap()
        
#if os(iOS) || os(visionOS)
        if window.horizontalSizeClass == .regular {
            window.staticTexts["NSMutableSet"].tap()
        }
#endif
        
        try write(screenshot: window.screenshot(), name: "4_image_list", description: "Image class list")
    }
}
