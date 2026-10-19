import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

/// Unified input controller combining hardware keyboard state (8-directional movement + fire + pause)
/// and on-screen virtual arcade controls.
@MainActor
@Observable
final class InputController {
    // Hardware keyboard state
    private var keyLeft: Bool = false
    private var keyRight: Bool = false
    private var keyUp: Bool = false
    private var keyDown: Bool = false
    private var keyFire: Bool = false

    // Virtual touch/mouse controls state
    var virtualLeft: Bool = false
    var virtualRight: Bool = false
    var virtualUp: Bool = false
    var virtualDown: Bool = false
    var virtualFire: Bool = false

    var onPauseToggle: (() -> Void)?
    var onEscapePressed: (() -> Void)?

    #if os(macOS)
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    #endif

    var isLeft: Bool { keyLeft || virtualLeft }
    var isRight: Bool { keyRight || virtualRight }
    var isUp: Bool { keyUp || virtualUp }
    var isDown: Bool { keyDown || virtualDown }
    var isFireHeld: Bool { keyFire || virtualFire }

    init() {}

    func startMonitoring() {
        #if os(macOS)
        stopMonitoring()
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handleKeyEvent(event, isDown: true) {
                return nil
            }
            return event
        }
        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self else { return event }
            if self.handleKeyEvent(event, isDown: false) {
                return nil
            }
            return event
        }
        #endif
    }

    func stopMonitoring() {
        #if os(macOS)
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
            self.keyUpMonitor = nil
        }
        #endif
        resetAll()
    }

    func resetAll() {
        keyLeft = false
        keyRight = false
        keyUp = false
        keyDown = false
        keyFire = false
        virtualLeft = false
        virtualRight = false
        virtualUp = false
        virtualDown = false
        virtualFire = false
    }

    #if os(macOS)
    private func handleKeyEvent(_ event: NSEvent, isDown: Bool) -> Bool {
        switch event.keyCode {
        case 123, 0: // Left Arrow or 'A'
            keyLeft = isDown
            return true
        case 124, 2: // Right Arrow or 'D'
            keyRight = isDown
            return true
        case 126, 13: // Up Arrow or 'W'
            keyUp = isDown
            return true
        case 125, 1: // Down Arrow or 'S'
            keyDown = isDown
            return true
        case 49, 6, 7, 36: // Space, 'Z', 'X', Return
            keyFire = isDown
            return true
        case 35: // 'P'
            if isDown && !event.isARepeat {
                onPauseToggle?()
            }
            return true
        case 53: // Escape
            if isDown && !event.isARepeat {
                onEscapePressed?()
            }
            return true
        default:
            return false
        }
    }
    #endif
}
