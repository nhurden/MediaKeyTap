//
//  ViewController.swift
//  MediaKeyTapExample
//
//  Created by Nicholas Hurden on 22/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Cocoa
import MediaKeyTap

class ViewController: NSViewController {
    @IBOutlet weak var playPauseLabel: NSTextField!
    @IBOutlet weak var previousLabel: NSTextField!
    @IBOutlet weak var rewindLabel: NSTextField!
    @IBOutlet weak var nextLabel: NSTextField!
    @IBOutlet weak var fastForwardLabel: NSTextField!

    var mediaKeyTap: MediaKeyTap?

    override func viewDidLoad() {
        super.viewDidLoad()

        mediaKeyTap = MediaKeyTap(delegate: self, on: .KeyDownAndUp)
        mediaKeyTap?.start()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func toggleLabel(label: NSTextField, enabled: Bool) {
        label.textColor = enabled ? NSColor.greenColor() : NSColor.textColor()
    }
}

extension ViewController: MediaKeyTapDelegate {
    func handleMediaKey(mediaKey: MediaKey, event: KeyEvent) {
        switch mediaKey {
        case .PlayPause:
            print("Play/pause pressed")
            toggleLabel(playPauseLabel, enabled: event.keyPressed)
        case .Previous:
            print("Previous pressed")
            toggleLabel(previousLabel, enabled: event.keyPressed)
        case .Rewind:
            print("Rewind pressed")
            toggleLabel(rewindLabel, enabled: event.keyPressed)
        case .Next:
            print("Next pressed")
            toggleLabel(nextLabel, enabled: event.keyPressed)
        case .FastForward:
            print("Fast Forward pressed")
            toggleLabel(fastForwardLabel, enabled: event.keyPressed)
        }
    }
}