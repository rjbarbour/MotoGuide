//
//  RideHorizonApp.swift
//  RideHorizon
//
//  Created by Robert Barbour on 10/07/2024.
//

import SwiftUI

@main
struct RideHorizonApp: App {
    var body: some Scene {
        WindowGroup {
            appContent
        }
    }

    private var appContent: some View {
        ContentView()
            .onAppear {
                Task {
                    do {
                        _ = try await ProxySessionCoordinator.shared.provisionSessionIfNeeded()
                    } catch {
                        ProxyDiagnostics.log("Auth", "Auto-provision attempt failed before launch: \(error.localizedDescription)")
                    }
                }
            }
    }
}
