//
//  MediaKeyTap.swift
//  Castle
//
//  Created by Nicholas Hurden on 16/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Cocoa

public enum MediaKey {
    case PlayPause
    case Previous
    case Next
    case Rewind
    case FastForward
}

public enum KeyPressMode {
    case KeyDown
    case KeyUp
    case KeyDownAndUp
}

public typealias Keycode = Int32
public typealias KeyFlags = Int32

public struct KeyEvent {
    public let keycode: Keycode
    public let keyFlags: KeyFlags
    public let keyPressed: Bool     // Will be true after a keyDown and false after a keyUp
    public let keyRepeat: Bool
}

public protocol MediaKeyTapDelegate {
    func handleMediaKey(mediaKey: MediaKey, event: KeyEvent)
}

public class MediaKeyTap {
    let delegate: MediaKeyTapDelegate
    let mediaApplicationWatcher: MediaApplicationWatcher
    let internals: MediaKeyTapInternals
    let keyPressMode: KeyPressMode

    var interceptMediaKeys: Bool {
        didSet {
            if interceptMediaKeys != oldValue {
                self.internals.enableTap(interceptMediaKeys)
            }
        }
    }

    // MARK: - Setup

    public init(delegate: MediaKeyTapDelegate, on mode: KeyPressMode = .KeyDown) {
        self.delegate = delegate
        self.interceptMediaKeys = false
        self.mediaApplicationWatcher = MediaApplicationWatcher()
        self.internals = MediaKeyTapInternals()
        self.keyPressMode = mode
    }

    public func start() {
        mediaApplicationWatcher.delegate = self
        mediaApplicationWatcher.start()

        internals.delegate = self
        do {
            try internals.startWatchingMediaKeys()
        } catch let error as EventTapError {
            mediaApplicationWatcher.stop()
            print(error.description)
        } catch {}
    }

    private func keycodeToMediaKey(keycode: Keycode) -> MediaKey? {
        switch keycode {
        case NX_KEYTYPE_PLAY: return .PlayPause
        case NX_KEYTYPE_PREVIOUS: return .Previous
        case NX_KEYTYPE_NEXT: return .Next
        case NX_KEYTYPE_REWIND: return .Rewind
        case NX_KEYTYPE_FAST: return .FastForward
        default: return nil
        }
    }

    private func shouldNotifyDelegate(event: KeyEvent) -> Bool {
        switch keyPressMode {
        case .KeyDown:
            return event.keyPressed
        case .KeyUp:
            return !event.keyPressed
        case .KeyDownAndUp:
            return true
        }
    }
}

extension MediaKeyTap: MediaApplicationWatcherDelegate {
    func updateIsActiveMediaApp(active: Bool) {
        interceptMediaKeys = active
    }

    // When a static whitelisted app starts, we need to restart the tap to ensure that
    // the dynamic whitelist is not overridden by the other app
    func whitelistedAppStarted() {
        do {
            try internals.restartTap()
        } catch let error as EventTapError {
            mediaApplicationWatcher.stop()
            print(error.description)
        } catch {}
    }
}

extension MediaKeyTap: MediaKeyTapInternalsDelegate {
    func updateInterceptMediaKeys(intercept: Bool) {
        interceptMediaKeys = intercept
    }

    func handleKeyEvent(event: KeyEvent) {
        if let key = keycodeToMediaKey(event.keycode) {
            if shouldNotifyDelegate(event) {
                delegate.handleMediaKey(key, event: event)
            }
        }
    }

    func isInterceptingMediaKeys() -> Bool {
        return interceptMediaKeys
    }
}