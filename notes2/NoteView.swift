//
//  NoteView.swift
//  notes2
//
//  Created by Lucio Cuddeford on 01/07/2025.
//

import SwiftUI
import SwiftData
import UIKit

struct NoteView: View {
    @Bindable var note: Note
    @Binding var selectedNoteID: UUID?
    @Environment(\.modelContext) private var context: ModelContext

    @State private var noteText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var editorCoordinator: RichTextEditor.Coordinator?
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject var settings = AppSettings.shared

    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false

    init(note: Note, selectedNoteID: Binding<UUID?>) {
        self._selectedNoteID = selectedNoteID
        self._note = Bindable(wrappedValue: note)

        if let attr = try? NSAttributedString(
            data: note.content,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil,
        ) {
            _noteText = State(initialValue: attr)
        } else {
            _noteText = State(initialValue: NSAttributedString(string: ""))
        }

        _selectedRange = State(initialValue: NSRange(location: note.cursorLocation, length: 0))
    }

    var body: some View {
        ZStack {
            RichTextEditor(
                text: $noteText,
                selectedRange: $selectedRange,
                note: note,
                keyboard: keyboard,
                onCoordinatorReady: { coordinator in
                    self.editorCoordinator = coordinator
                    if noteText.length == 0 {
                        coordinator.toggleAttribute(.title1)
                    }

                    editorCoordinator?.textView?.becomeFirstResponder()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        editorCoordinator?.textView?.becomeFirstResponder()
                    }
                },
            )
            .onChange(of: noteText) { oldValue, newValue in
                if let data = try? newValue.data(
                    from: NSRange(location: 0, length: newValue.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd],
                ) {
                    note.content = data
                    note.updatedAt = Date()
                }
            }

            if isDragging {
                NewNoteIndicatorView(translation: dragOffset, location: dragLocation)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 25, coordinateSpace: .global)
                .onChanged { value in
                    // Only activate if the drag starts from the right edge of the screen
                    if value.startLocation.x > UIScreen.main.bounds.width - 50 {
                        // Set the location first
                        dragOffset = value.translation
                        dragLocation = value.location

                        // Then animate the appearance if it's not already visible
                        if !isDragging {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDragging = true
                            }
                        }
                    }
                }
                .onEnded { value in
                    if isDragging, value.translation.width < -100 { // Swipe left
                        let newNote = Note()
                        context.insert(newNote)
                        selectedNoteID = nil
                        DispatchQueue.main.async {
                            selectedNoteID = newNote.id
                        }
                    }
                    // Reset drag state
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDragging = false
                    }
                    dragOffset = .zero
                    dragLocation = .zero
                }
        )
        .ignoresSafeArea()
        .toolbar(UIDevice.current.userInterfaceIdiom == .phone ? .hidden : .visible, for: .navigationBar)
        .onAppear {
            UserDefaults.standard.set(note.id.uuidString, forKey: "lastOpenedNoteID")
        }
        .onDisappear {
            UserDefaults.standard.removeObject(forKey: "lastOpenedNoteID")
        }
    }
}
