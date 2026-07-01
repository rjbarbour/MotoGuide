//
//  MotoGuideApp.swift
//  MotoGuide
//
//  Created by Robert Barbour on 10/07/2024.
//

import SwiftUI

@main
struct MotoGuideApp: App {
    init() {
        #if DEBUG
        DebugProxyTokenImporter.importFromEnvironment()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
