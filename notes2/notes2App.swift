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
        AppSettings.registerDefaults()

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
                .onAppear {
                    // Check if it's the first launch and create a default note if needed.
                    let defaults = UserDefaults.standard
                    if !defaults.bool(forKey: "hasLaunchedBefore") {
                        createDefaultNoteIfNeeded()
                        defaults.set(true, forKey: "hasLaunchedBefore")
                    }
                }
        }
        .modelContainer(container)
    }

    private func createDefaultNoteIfNeeded() {
        // Access the main context from the container.
        let context = container.mainContext
        // Create a fetch descriptor to check for existing notes.
        let fetchDescriptor = FetchDescriptor<Note>()

        do {
            // Fetch notes.
            let notes = try context.fetch(fetchDescriptor)
            // If no notes exist, insert the default one.
            if notes.isEmpty {
                insertDefaultNote(context: context)
            }
        } catch {
            // Handle potential fetch errors.
            print("Failed to fetch notes: \(error)")
        }
    }

    private func insertDefaultNote(context: ModelContext) {
        let base64EncodedRTFD = "cnRmZAAAAAADAAAAAgAAAAcAAABUWFQucnRmAQAAAC5sBAAAKwAAAAEAAABkBAAAe1xydGYxXGFuc2lcYW5zaWNwZzEyNTJcY29jb2FydGYyODIyClxjb2NvYXRleHRzY2FsaW5nMVxjb2NvYXBsYXRmb3JtMXtcZm9udHRibFxmMFxmbmlsXGZjaGFyc2V0MCAuU0ZVSS1Cb2xkO30Ke1xjb2xvcnRibDtccmVkMjU1XGdyZWVuMjU1XGJsdWUyNTU7XHJlZDI1NVxncmVlbjI1NVxibHVlMjU1O30Ke1wqXGV4cGFuZGVkY29sb3J0Ymw7O1xjc2dyYXlcYzEwMDAwMFxjbmFtZSBsYWJlbENvbG9yO30KXHBhcmRcdHg1NjBcdHgxMTIwXHR4MTY4MFx0eDIyNDBcdHgyODAwXHR4MzM2MFx0eDM5MjBcdHg0NDgwXHR4NTA0MFx0eDU2MDBcdHg2MTYwXHR4NjcyMFxzbC05Mjhcc2E1MDAwXHBhcnRpZ2h0ZW5mYWN0b3IwCgpcZjBcYlxmczU2IFxjZjIgV2VsY29tZSB0byBTcHJpbmcsIGEgbWluaW1hbCBzdHJlYW0gb2YgY29uc2Npb3VzbmVzcyB3cml0aW5nIGFwcC5cClxwYXJkXHR4NTYwXHR4MTEyMFx0eDE2ODBcdHgyMjQwXHR4MjgwMFx0eDMzNjBcdHgzOTIwXHR4NDQ4MFx0eDUwNDBcdHg1NjAwXHR4NjE2MFx0eDY3MjBcc2wtOTI4XHNhNjQwXHBhcnRpZ2h0ZW5mYWN0b3IwClxjZjIgUmVsYXRlZCB0aG91Z2h0cyBzaXQgY2xvc2UgdG9nZXRoZXIgaW4gYSBzdHJlYW0uXApVbnJlbGF0ZWQgdGhvdWdodHMgc2l0IGZhciBhcGFydC5cClxwYXJkXHR4NTYwXHR4MTEyMFx0eDE2ODBcdHgyMjQwXHR4MjgwMFx0eDMzNjBcdHgzOTIwXHR4NDQ4MFx0eDUwNDBcdHg1NjAwXHR4NjE2MFx0eDY3MjBcc2wtOTI4XHNhNTAwMFxwYXJ0aWdodGVuZmFjdG9yMApcY2YyIFBpbmNoIHJlbGF0ZWQgdGhvdWdodHMgdG9nZXRoZXIgYW5kIHVucmVsYXRlZCB0aG91Z2h0cyBhcGFydC5cCkhvbGQgYW5kIGRyYWcgYSB0aG91Z2h0IHRvIG1vdmUgaXQgdXAgb3IgZG93blwKXHBhcmRcdHg1NjBcdHgxMTIwXHR4MTY4MFx0eDIyNDBcdHgyODAwXHR4MzM2MFx0eDM5MjBcdHg0NDgwXHR4NTA0MFx0eDU2MDBcdHg2MTYwXHR4NjcyMFxzbC05Mjhcc2E2NDBccGFydGlnaHRlbmZhY3RvcjAKXGNmMiBTd2lwZSBmcm9tIGxlZnQgdG8gXCc5M3JlcGx5XCc5NCB0byBhIHRob3VnaHQgYW5kIGFkZCBhIHRob3VnaHQgZGlyZWN0bHkgYmVsb3dcClN3aXBlIGZyb20gcmlnaHQgdG8gZGVsZXRlIGEgdGhvdWdodH0BAAAAIwAAAAEAAAAHAAAAVFhULnJ0ZhAAAABjTZNotgEAAAAAAAAAAAAA"

        if let data = Data(base64Encoded: base64EncodedRTFD) {
            let newNote = Note(
                content: data,
                isPinned: false,
            )
            context.insert(newNote)
            do {
                try context.save()
            } catch {
                print("Failed to save default note: \(error)")
            }
        } else {
            print("Failed to decode base64 string for default note.")
        }
    }
}
