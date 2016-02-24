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

protocol MediaKeyTapInternalsDelegate {
    func updateInterceptMediaKeys(intercept: Bool)
    func handleKeyEvent(event: KeyEvent)
    func isInterceptingMediaKeys() -> Bool
}

class MediaKeyTapInternals {
    typealias EventTapCallback = @convention(block) (CGEventTapProxy, CGEventType, CGEvent) -> CGEvent?

    var delegate: MediaKeyTapInternalsDelegate?
    var keyEventPort: CFMachPort?
    var runLoopSource: CFRunLoopSourceRef?
    var callback: EventTapCallback?
    var runLoopQueue: dispatch_queue_t?
    var runLoop: CFRunLoopRef?

    deinit {
        stopWatchingMediaKeys()
    }

    /**
        Enable/Disable the underlying tap
    */
    func enableTap(onOff: Bool) {
        if let port = self.keyEventPort, runLoop = self.runLoop {
            CFRunLoopPerformBlock(runLoop, kCFRunLoopCommonModes) {
                CGEventTapEnable(port, onOff)
            }
            CFRunLoopWakeUp(runLoop)
        }
    }

    func restartTap() {
        print("Restarting Media Key Tap")

        stopWatchingMediaKeys()
        startWatchingMediaKeys(restart: true)
    }

    func startWatchingMediaKeys(restart restart: Bool = false) {
        let eventTapCallback: EventTapCallback = { proxy, type, event in
            if type == .TapDisabledByTimeout {
                if let port = self.keyEventPort {
                    CGEventTapEnable(port, true)
                }
                return event
            } else if type == .TapDisabledByUserInput {
                return event
            }

            if let nsEvent = NSEvent(CGEvent: event) {
                guard type.rawValue == UInt32(NX_SYSDEFINED) else { return event }
                guard self.isKeyEvent(nsEvent) else { return event }

                let keycode = self.extractKeyCode(nsEvent)
                guard self.isMediaKey(keycode) else { return event }

                guard self.delegate?.isInterceptingMediaKeys() ?? false else { return event }

                dispatch_async(dispatch_get_main_queue()) {
                    self.delegate?.handleKeyEvent(self.toKeyEvent(nsEvent))
                }

                return nil
            }
            
            return event
        }

        startKeyEventTapWithCallback(eventTapCallback, restart: restart)
        callback = eventTapCallback
    }

    func stopWatchingMediaKeys() {
        CFRunLoopSourceInvalidate <^> runLoopSource
        CFRunLoopStop <^> runLoop
        CFMachPortInvalidate <^> keyEventPort
    }

    private func startKeyEventTapWithCallback(callback: EventTapCallback, restart: Bool) {
        // On a restart we don't want to interfere with the application watcher
        if !restart {
            delegate?.updateInterceptMediaKeys(true)
        }

        keyEventPort = keyCaptureEventTapPortWithCallback(callback)

        guard let port = keyEventPort else {
            print("Global event tap unavailable")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, port, 0)

        guard let source = runLoopSource else {
            print("Failed to create event tap runloop source")
            return
        }

        let queue = dispatch_queue_create("MediaKeyTap Runloop", DISPATCH_QUEUE_SERIAL)
        self.runLoopQueue = queue

        dispatch_async(queue) {
            self.runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(self.runLoop, source, kCFRunLoopCommonModes)
            CFRunLoopRun()
        }
    }

    private func keyCaptureEventTapPortWithCallback(callback: EventTapCallback) -> CFMachPortRef? {
        let cCallback: CGEventTapCallBack = { proxy, type, event, refcon in
            let innerBlock = unsafeBitCast(refcon, EventTapCallback.self)
            return innerBlock(proxy, type, event).map(Unmanaged.passUnretained)
        }

        let refcon = unsafeBitCast(callback, UnsafeMutablePointer<Void>.self)

        return CGEventTapCreate(
            .CGSessionEventTap,
            .HeadInsertEventTap,
            .Default,
            CGEventMask(1 << NX_SYSDEFINED),
            cCallback,
            refcon)
    }

    private func isKeyEvent(event: NSEvent) -> Bool {
        return event.subtype.rawValue == 8
    }

    private func extractKeyCode(event: NSEvent) -> Keycode {
        return Keycode((event.data1 & 0xffff0000) >> 16)
    }

    private func toKeyEvent(event: NSEvent) -> KeyEvent {
        let keycode = extractKeyCode(event)
        let keyFlags = KeyFlags(event.data1 & 0x0000ffff)
        let keyPressed = ((keyFlags & 0xff00) >> 8) == 0xa
        let keyRepeat = (keyFlags & 0x1) == 0x1

        return KeyEvent(keycode: keycode, keyFlags: keyFlags, keyPressed: keyPressed, keyRepeat: keyRepeat)
    }

    private func isMediaKey(keycode: Keycode) -> Bool {
        return [NX_KEYTYPE_PLAY, NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST, NX_KEYTYPE_REWIND].contains(keycode)
    }
}