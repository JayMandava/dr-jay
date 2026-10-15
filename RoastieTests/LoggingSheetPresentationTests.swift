import SwiftUI
import UIKit
import XCTest
@testable import Roastie

/// Presents the real logging views, without saving entries, and compares
/// their onscreen geometry after the keyboard/presentation animations finish.
final class LoggingSheetPresentationTests: XCTestCase {
    @MainActor
    func testPresenceMatchesFoodAndExercisePresentation() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        var frames: [String: CGRect] = [:]
        for kind in [LoggingSheetKind.food, .exercise, .presence] {
            let window = UIWindow(windowScene: scene)
            window.frame = scene.coordinateSpace.bounds
            window.windowLevel = .normal + 1
            let host = UIHostingController(rootView: LoggingSheetHost(kind: kind))
            window.rootViewController = host
            window.makeKeyAndVisible()
            // Let the sheet and automatically focused keyboard settle.
            try await Task.sleep(for: .seconds(3))
            let presented = try XCTUnwrap(host.presentedViewController, "Missing \(kind.rawValue) sheet")
            frames[kind.rawValue] = presented.view.convert(presented.view.bounds, to: window)
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "logging-sheet-\(kind.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            // Also leave an inspectable image in this simulator app's tmp dir.
            let imageURL = FileManager.default.temporaryDirectory.appending(path: "logging-sheet-\(kind.rawValue).png")
            try image.pngData()?.write(to: imageURL)
            print("LOGGING_SHEET \(kind.rawValue) \(frames[kind.rawValue]!) IMAGE \(imageURL.path)")
            host.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            try await Task.sleep(for: .milliseconds(300))
        }
        let food = try XCTUnwrap(frames["food"])
        let exercise = try XCTUnwrap(frames["exercise"])
        let presence = try XCTUnwrap(frames["presence"])
        XCTAssertEqual(food.width, exercise.width, accuracy: 2)
        XCTAssertEqual(food.height, exercise.height, accuracy: 2)
        XCTAssertEqual(presence.width, food.width, accuracy: 2)
        XCTAssertEqual(presence.height, food.height, accuracy: 2)
        XCTAssertEqual(presence.minY, food.minY, accuracy: 2)
    }
}

private enum LoggingSheetKind: String { case food, exercise, presence }

private struct LoggingSheetHost: View {
    let kind: LoggingSheetKind
    @State private var isPresented = false

    var body: some View {
        Color.clear
            .onAppear { isPresented = true }
            .sheet(isPresented: $isPresented) {
                switch kind {
                case .food: LogFoodSheet(onSave: { _ in nil }, onLogged: { _ in })
                case .exercise: LogExerciseSheet(onSave: { _ in nil })
                case .presence: LogPresenceSheet()
                }
            }
    }
}
