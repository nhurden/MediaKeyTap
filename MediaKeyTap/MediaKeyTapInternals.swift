//
//  MediaKeyTapInternals.swift
//  Castle
//
//  A wrapper around the C APIs required for a CGEventTap
//
//  Created by Nicholas Hurden on 18/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Cocoa
import CoreGraphics

enum EventTapError: Error {
    case eventTapCreationFailure
    case runLoopSourceCreationFailure
}

extension EventTapError: CustomStringConvertible {
    var description: String {
        switch self {
        case .eventTapCreationFailure: return "Event tap creation failed: is your application sandboxed?"
        case .runLoopSourceCreationFailure: return "Runloop source creation failed"
        }
    }
}

protocol MediaKeyTapInternalsDelegate {
    func updateInterceptMediaKeys(_ intercept: Bool)
    func handle(keyEvent: KeyEvent)
    func isInterceptingMediaKeys() -> Bool
}

class MediaKeyTapInternals {
    typealias EventTapCallback = @convention(block) (CGEventType, CGEvent) -> CGEvent?

    var delegate: MediaKeyTapInternalsDelegate?
    var keyEventPort: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var callback: EventTapCallback?
    var runLoopQueue: DispatchQueue?
    var runLoop: CFRunLoop?

    deinit {
        stopWatchingMediaKeys()
    }

    /**
        Enable/Disable the underlying tap
    */
    func enableTap(_ onOff: Bool) {
        if let port = self.keyEventPort, let runLoop = self.runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes as CFTypeRef!) {
                CGEvent.tapEnable(tap: port, enable: onOff)
            }
            CFRunLoopWakeUp(runLoop)
        }
    }

    /**
        Restart the tap, placing it in front of existing taps
    */
    func restartTap() throws {
        stopWatchingMediaKeys()
        try startWatchingMediaKeys(restart: true)
    }

    func startWatchingMediaKeys(restart: Bool = false) throws {
        let eventTapCallback: EventTapCallback = { type, event in
            if type == .tapDisabledByTimeout {
                if let port = self.keyEventPort {
                    CGEvent.tapEnable(tap: port, enable: true)
                }
                return event
            } else if type == .tapDisabledByUserInput {
                return event
            }

            return self.handleEvent(event, ofType: type)
        }

        try startKeyEventTapWithCallback(eventTapCallback, restart: restart)
        callback = eventTapCallback
    }

    func stopWatchingMediaKeys() {
        CFRunLoopSourceInvalidate <^> runLoopSource
        CFRunLoopStop <^> runLoop
        CFMachPortInvalidate <^> keyEventPort
    }

    fileprivate func handleEvent(_ event: CGEvent, ofType type: CGEventType) -> CGEvent? {
        if let nsEvent = NSEvent(cgEvent: event) {
            guard type.rawValue == UInt32(NX_SYSDEFINED)
                && isMediaKeyEvent(nsEvent)
                && delegate?.isInterceptingMediaKeys() ?? false
            else { return event }

            DispatchQueue.main.async {
                self.delegate?.handle(keyEvent: self.toKeyEvent(nsEvent))
            }

            return nil
        }

        return event
    }

    fileprivate func startKeyEventTapWithCallback(_ callback: EventTapCallback, restart: Bool) throws {
        // On a restart we don't want to interfere with the application watcher
        if !restart {
            delegate?.updateInterceptMediaKeys(true)
        }

        keyEventPort = keyCaptureEventTapPortWithCallback(callback)
        guard let port = keyEventPort else { throw EventTapError.eventTapCreationFailure }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, port, 0)
        guard let source = runLoopSource else { throw EventTapError.runLoopSourceCreationFailure }

        let queue = DispatchQueue(label: "MediaKeyTap Runloop", attributes: [])
        self.runLoopQueue = queue

        queue.async {
            self.runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(self.runLoop, source, CFRunLoopMode.commonModes)
            CFRunLoopRun()
        }
    }

    fileprivate func keyCaptureEventTapPortWithCallback(_ callback: EventTapCallback) -> CFMachPort? {
        let cCallback: CGEventTapCallBack = { proxy, type, event, refcon in
            let innerBlock = unsafeBitCast(refcon, to: EventTapCallback.self)
            return innerBlock(type, event).map(Unmanaged.passUnretained)
        }

        let refcon = unsafeBitCast(callback, to: UnsafeMutableRawPointer.self)

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << NX_SYSDEFINED),
            callback: cCallback,
            userInfo: refcon)
    }

    fileprivate func isKeyEvent(_ event: NSEvent) -> Bool {
        return event.subtype.rawValue == 8
    }

    fileprivate func extractKeyCode(_ event: NSEvent) -> Keycode {
        return Keycode((event.data1 & 0xffff0000) >> 16)
    }

    fileprivate func toKeyEvent(_ event: NSEvent) -> KeyEvent {
        let keycode = extractKeyCode(event)
        let keyFlags = KeyFlags(event.data1 & 0x0000ffff)
        let keyPressed = ((keyFlags & 0xff00) >> 8) == 0xa
        let keyRepeat = (keyFlags & 0x1) == 0x1

        return KeyEvent(keycode: keycode, keyFlags: keyFlags, keyPressed: keyPressed, keyRepeat: keyRepeat)
    }

    fileprivate func isMediaKeyEvent(_ event: NSEvent) -> Bool {
        let keycode = extractKeyCode(event)
        return isKeyEvent(event)
            && [NX_KEYTYPE_PLAY, NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST, NX_KEYTYPE_REWIND].contains(keycode)
    }
}
