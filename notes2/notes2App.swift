//
//  notes2App.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI
import SwiftData

@main
struct notes2App: App {
    let container: ModelContainer
    
    init() {
        do {
            let storeURL = URL.storeURL(for: "group.com.cuddeford.notes2", databaseName: "notes")
            let configuration = ModelConfiguration(url: storeURL)
            container = try ModelContainer(for: Note.self, configurations: configuration)
        } catch {
            fatalError("Failed to configure SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
