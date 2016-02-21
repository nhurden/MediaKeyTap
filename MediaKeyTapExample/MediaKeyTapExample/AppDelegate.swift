//
//  AppDelegate.swift
//  MediaKeyTapExample
//
//  Created by Nicholas Hurden on 22/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Cocoa
import MediaKeyTap

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var mediaKeyTap: MediaKeyTap?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        mediaKeyTap = MediaKeyTap(delegate: self)
        mediaKeyTap?.start()
    }
}

extension AppDelegate: MediaKeyTapDelegate {
    func handleMediaKey(mediaKey: MediaKey, withEvent: KeyEvent) {
        switch mediaKey {
        case .PlayPause:
            print("Play/pause pressed")
        case .Previous, .Rewind:
            print("Previous pressed")
        case .Next, .FastForward:
            print("Next pressed")
        }
    }
}