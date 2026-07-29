//
//  Tour_of_the_AlpsApp.swift
//  Tour of the Alps
//
//  Created by Giulio Carloni on 28/07/2026.
//

import SwiftUI

@main
struct Tour_of_the_AlpsApp: App {
    init() {
        BrandFont.registerIfNeeded()
        configureImageCache()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    /// Race content is static and image-heavy, so give `AsyncImage` a generous shared
    /// cache — it's what makes previously visited screens work offline.
    private func configureImageCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024
        )
    }
}
