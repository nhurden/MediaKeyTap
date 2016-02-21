//
//  MediaApplicationWatcher.swift
//  Castle
//
//  Maintains a list of active media applications.
//
//  Created by Nicholas Hurden on 18/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Cocoa

protocol MediaApplicationWatcherDelegate {
    func updateIsActiveMediaApp(active: Bool)
}

class MediaApplicationWatcher {
    var mediaApps: [NSRunningApplication]
    var delegate: MediaApplicationWatcherDelegate?

    init() {
        self.mediaApps = []
    }

    deinit {
        NSWorkspace.sharedWorkspace().notificationCenter.removeObserver(self)
    }

    func start() {
        let notificationCenter = NSWorkspace.sharedWorkspace().notificationCenter

        notificationCenter.addObserver(self,
            selector: "applicationActivated:",
            name: NSWorkspaceDidActivateApplicationNotification,
            object: nil)

        notificationCenter.addObserver(self,
            selector: "applicationTerminated:",
            name: NSWorkspaceDidTerminateApplicationNotification,
            object: nil)
    }

    // MARK: - Notifications

    @objc private func applicationActivated(notification: NSNotification) {
        if let application = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication {
            guard whitelisted(application) else { return }

            mediaApps = mediaApps.filter { $0 != application }
            mediaApps.insert(application, atIndex: 0)
            updateKeyInterceptStatus()
        }
    }

    @objc private func applicationTerminated(notification: NSNotification) {
        if let application = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication {
            mediaApps = mediaApps.filter { $0 != application }
            updateKeyInterceptStatus()
        }
    }

    private func updateKeyInterceptStatus() {
        guard mediaApps.count > 0 else { return }

        let activeApp = mediaApps.first!
        let ownApp = NSRunningApplication.currentApplication()

        delegate?.updateIsActiveMediaApp(activeApp == ownApp)
    }

    // MARK: - Identifier Whitelist

    // The SPMediaKeyTap whitelist
    func whitelistedApplicationIdentifiers() -> [String] {
        var whitelist = [
            "at.justp.Theremin",
            "co.rackit.mate",
            "com.Timenut.SongKey",
            "com.apple.Aperture",
            "com.apple.QuickTimePlayerX",
            "com.apple.iPhoto",
            "com.apple.iTunes",
            "com.apple.iWork.Keynote",
            "com.apple.quicktimeplayer",
            "com.beardedspice.BeardedSpice",
            "com.beatport.BeatportPro",
            "com.bitcartel.pandorajam",
            "com.ilabs.PandorasHelper",
            "com.jriver.MediaCenter18",
            "com.jriver.MediaCenter19",
            "com.jriver.MediaCenter20",
            "com.macromedia.fireworks", // the tap messes up their mouse input
            "com.mahasoftware.pandabar",
            "com.netease.163music",
            "com.plexsquared.Plex",
            "com.plug.Plug",
            "com.plug.Plug2",
            "com.soundcloud.desktop",
            "com.spotify.client",
            "com.ttitt.b-music",
            "fm.last.Last.fm",
            "fm.last.Scrobbler",
            "org.clementine-player.clementine",
            "org.niltsh.MPlayerX",
            "org.quodlibet.quodlibet",
            "org.videolan.vlc",
            "ru.ya.themblsha.YandexMusic"
        ]

        if let ownIdentifier = NSBundle.mainBundle().bundleIdentifier {
            whitelist.append(ownIdentifier)
        }

        return whitelist
    }

    private func whitelisted(application: NSRunningApplication) -> Bool {
        if let bundleIdentifier = application.bundleIdentifier {
            return whitelistedApplicationIdentifiers().contains(bundleIdentifier)
        } else {
            return false
        }
    }
}