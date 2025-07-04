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
            documentAttributes: nil
        ) {
            _noteText = State(initialValue: attr)
        } else {
            _noteText = State(initialValue: NSAttributedString(string: ""))
        }

        _selectedRange = State(initialValue: NSRange(location: note.cursorLocation, length: 0))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RichTextEditor(
                text: $noteText,
                selectedRange: $selectedRange,
                note: note,
                keyboard: keyboard,
                onCoordinatorReady: { coordinator in
                    self.editorCoordinator = coordinator
                }
            )
            .onAppear {
                // Initial parsing and spatial property update when the view appears
                editorCoordinator?.parseAttributedText(noteText)
            }
            .onChange(of: noteText) { oldValue, newValue in
                if let data = try? newValue.data(
                    from: NSRange(location: 0, length: newValue.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                ) {
                    note.content = data
                    note.updatedAt = Date()
                }
                // Re-parse and update spatial properties when noteText changes
                editorCoordinator?.parseAttributedText(newValue)
            }
            .onChange(of: editorCoordinator?.paragraphs) { oldParagraphs, newParagraphs in
                // Handle changes in paragraphs, e.g., update UI based on spatial properties
                // print("Paragraphs changed: \(newParagraphs?.count ?? 0) paragraphs")
                // You can now access newParagraphs[i].height, newParagraphs[i].screenPosition, etc.
            }

            // Overlay for paragraph backgrounds
            if let paragraphs = editorCoordinator?.paragraphs, let textContainerInset = editorCoordinator?.textContainerInset, let contentOffset = editorCoordinator?.contentOffset, let textViewWidth = editorCoordinator?.textViewWidth {
                ForEach(paragraphs.indices, id: \.self) { index in
                    let paragraph = paragraphs[index]
                    Rectangle()
                        .fill(Color.gray.opacity(0.2)) // Light grey background
                        .cornerRadius(10)
                        .frame(width: textViewWidth - textContainerInset.left - textContainerInset.right, height: paragraph.height)
                        .offset(x: paragraph.screenPosition.x, y: paragraph.screenPosition.y)
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
