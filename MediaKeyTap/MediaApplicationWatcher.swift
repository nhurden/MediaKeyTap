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
    func whitelistedAppStarted()
}

class MediaApplicationWatcher {
    var mediaApps: [NSRunningApplication]
    var delegate: MediaApplicationWatcherDelegate?

    // A set of bundle identifiers that notifications have been received from
    var dynamicWhitelist: Set<String>

    let mediaKeyTapDidStartNotification = "MediaKeyTapDidStart" // Sent on start()
    let mediaKeyTapReplyNotification = "MediaKeyTapReply" // Sent on receipt of a mediaKeyTapDidStartNotification

    init() {
        self.mediaApps = []
        self.dynamicWhitelist = []
    }

    deinit {
        stop()
    }

    func start() {
        let notificationCenter = NSWorkspace.sharedWorkspace().notificationCenter

        notificationCenter.addObserver(self,
                                       selector: #selector(applicationLaunched),
                                       name: NSWorkspaceDidLaunchApplicationNotification,
                                       object: nil)

        notificationCenter.addObserver(self,
                                       selector: #selector(applicationActivated),
                                       name: NSWorkspaceDidActivateApplicationNotification,
                                       object: nil)

        notificationCenter.addObserver(self,
                                       selector: #selector(applicationTerminated),
                                       name: NSWorkspaceDidTerminateApplicationNotification,
                                       object: nil)

        setupDistributedNotifications()
    }

    func stop() {
        NSWorkspace.sharedWorkspace().notificationCenter.removeObserver(self)
    }

    func setupDistributedNotifications() {
        let distributedNotificationCenter = NSDistributedNotificationCenter.defaultCenter()

        // Notify any other apps using this library using a distributed notification
        // deliverImmediately is needed to ensure that backgrounded apps can resign the
        // media tap immediately when new media apps are launched
        let ownBundleIdentifier = NSBundle.mainBundle().bundleIdentifier

        distributedNotificationCenter.postNotificationName(mediaKeyTapDidStartNotification, object: ownBundleIdentifier, userInfo: nil, deliverImmediately: true)

        distributedNotificationCenter.addObserverForName(mediaKeyTapDidStartNotification, object: nil, queue: nil) { notification in
            if let otherBundleIdentifier = notification.object as? String {
                guard otherBundleIdentifier != ownBundleIdentifier else { return }
                self.dynamicWhitelist.insert(otherBundleIdentifier)

                // Send a reply so that the sender knows that this app exists
                distributedNotificationCenter.postNotificationName(self.mediaKeyTapReplyNotification, object: ownBundleIdentifier, userInfo: nil, deliverImmediately: true)
            }
        }

        distributedNotificationCenter.addObserverForName(mediaKeyTapReplyNotification, object: nil, queue: nil) { notification in
            if let otherBundleIdentifier = notification.object as? String {
                guard otherBundleIdentifier != ownBundleIdentifier else { return }
                self.dynamicWhitelist.insert(otherBundleIdentifier)
            }
        }
    }

    // MARK: - Notifications

    @objc private func applicationLaunched(notification: NSNotification) {
        if let application = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication {
            if inStaticWhitelist(application) && application != NSRunningApplication.currentApplication() {
                delegate?.whitelistedAppStarted()
            }
        }
    }

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

    // The static SPMediaKeyTap whitelist
    func whitelistedApplicationIdentifiers() -> Set<String> {
        var whitelist: Set<String> = [
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
            whitelist.insert(ownIdentifier)
        }

        return whitelist
    }

    private func inStaticWhitelist(application: NSRunningApplication) -> Bool {
        return (whitelistedApplicationIdentifiers().contains <^> application.bundleIdentifier) ?? false
    }

    private func inDynamicWhitelist(application: NSRunningApplication) -> Bool {
        return (dynamicWhitelist.contains <^> application.bundleIdentifier) ?? false
    }

    private func whitelisted(application: NSRunningApplication) -> Bool {
        return inStaticWhitelist(application) || inDynamicWhitelist(application)
    }
}