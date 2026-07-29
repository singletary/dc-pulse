//
//  DCPulseApp.swift
//  DCPulse
//
//  Created by Michael Singletary on 7/11/26.
//

import SwiftUI
import SwiftData

@main
struct DCPulseApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var appDelegate

    init() {
        MapPerformanceDiagnostics.shared.milestone(
            .appLaunch,
            context: MapPerformanceContext(),
            itemCount: 0
        )
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [
            WatchedPulseItem.self,
            FollowedPlace.self,
            PulseObservationRecord.self,
            PulseStateSnapshotRecord.self,
            InAppNotification.self
        ])
    }
}
