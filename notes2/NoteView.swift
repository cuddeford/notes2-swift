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
    @Environment(\.dismiss) private var dismiss

    @State private var noteText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var editorCoordinator: RichTextEditor.Coordinator?
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject var settings = AppSettings.shared

    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var isAtBottom = true
    @State private var canScroll = false
    @State private var isStatusBarHidden = false

    static private func noteTextStyle(for aFont: UIFont) -> NoteTextStyle {
        let title1Size = UIFont.preferredFont(forTextStyle: .title1).pointSize
        let title2Size = UIFont.preferredFont(forTextStyle: .title2).pointSize

        switch aFont.pointSize {
        case title1Size:
            return .title1
        case title2Size:
            return .title2
        default:
            return .body
        }
    }

    init(note: Note, selectedNoteID: Binding<UUID?>) {
        self._selectedNoteID = selectedNoteID
        self._note = Bindable(wrappedValue: note)

        var loadedText: NSAttributedString
        // Attempt to load attributed string from note data
        if let attr = try? NSAttributedString(
            data: note.content,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        ), attr.length > 0 {
            // If successful and not empty, reconstruct attributes to ensure correct metrics
            let mutableAttr = NSMutableAttributedString(attributedString: attr)
            mutableAttr.beginEditing()
            mutableAttr.enumerateAttributes(in: NSRange(location: 0, length: mutableAttr.length), options: []) { attributes, range, _ in
                guard let oldFont = attributes[.font] as? UIFont else { return }

                // Determine style and traits from the old font
                let style = NoteView.noteTextStyle(for: oldFont)
                let traits = oldFont.fontDescriptor.symbolicTraits

                // Create a fresh font with the correct metrics
                let newFont = UIFont.noteStyle(style, traits: traits)

                // Create a fresh paragraph style, preserving original spacing
                let oldParagraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
                let newParagraphStyle = (oldParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                newParagraphStyle.minimumLineHeight = newFont.lineHeight
                newParagraphStyle.maximumLineHeight = newFont.lineHeight

                // Apply the fresh attributes
                mutableAttr.addAttribute(.font, value: newFont, range: range)
                mutableAttr.addAttribute(.paragraphStyle, value: newParagraphStyle, range: range)
            }
            mutableAttr.endEditing()
            loadedText = mutableAttr
        } else {
            // If loading fails or note is empty, create a new note with style based on user preference
            let useBigFont = UserDefaults.standard.bool(forKey: "newNoteWithBigFont")
            let style: NoteTextStyle = useBigFont ? .title1 : .body
            let traits: UIFontDescriptor.SymbolicTraits = useBigFont ? .traitBold : []
            let newFont = UIFont.noteStyle(style, traits: traits)
            let newParagraphStyle = NSMutableParagraphStyle()
            newParagraphStyle.paragraphSpacing = AppSettings.shared.defaultParagraphSpacing
            newParagraphStyle.minimumLineHeight = newFont.lineHeight
            newParagraphStyle.maximumLineHeight = newFont.lineHeight
            let attributes: [NSAttributedString.Key: Any] = [
                .font: newFont,
                .paragraphStyle: newParagraphStyle,
                .foregroundColor: UIColor.label
            ]
            // Create an empty string but with these typing attributes for the editor
            loadedText = NSAttributedString(string: "", attributes: attributes)
        }

        _noteText = State(initialValue: loadedText)
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
                },
                isAtBottom: $isAtBottom,
                canScroll: $canScroll
            )
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

            if isDragging {
                NewNoteIndicatorView(translation: dragOffset, location: dragLocation)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .padding()
                            .opacity(0.5)
                    }
                    .padding(.trailing, 15)
                }
                Spacer()
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
                        selectedNoteID = newNote.id
                    }
                    // Reset drag state
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDragging = false
                    }
                    dragOffset = .zero
                    dragLocation = .zero
                }
        )
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .overlay(
            EditorToolbarOverlay(
                keyboard: keyboard,
                settings: settings,
                onBold: { editorCoordinator?.toggleAttribute(.bold) },
                onItalic: { editorCoordinator?.toggleAttribute(.italic) },
                onUnderline: { editorCoordinator?.toggleAttribute(.underline) },
                onTitle1: { editorCoordinator?.toggleAttribute(.title1) },
                onTitle2: { editorCoordinator?.toggleAttribute(.title2) },
                onBody: { editorCoordinator?.toggleAttribute(.body) },
                onScrollToBottom: { editorCoordinator?.scrollToBottom() },
                isAtBottom: isAtBottom,
                canScroll: canScroll
            )
        )
        .onAppear {
            isStatusBarHidden = true
            UserDefaults.standard.set(note.id.uuidString, forKey: "lastOpenedNoteID")
        }
        .onDisappear {
            isStatusBarHidden = false
            UserDefaults.standard.removeObject(forKey: "lastOpenedNoteID")
        }
        .statusBar(hidden: isStatusBarHidden)
    }
}
