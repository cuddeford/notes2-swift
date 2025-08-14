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
    var isPreview: Bool? = false
    @Binding var selectedNoteID: UUID?
    @Environment(\.modelContext) private var context: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var noteText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @StateObject private var coordinatorHolder = CoordinatorHolder()
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject var settings = AppSettings.shared

    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    @State private var dragActivationPoint: Double = 75
    @State private var isDragging = false

    @State private var dismissDragOffset: CGSize = .zero
    @State private var dismissDragLocation: CGPoint = .zero
    @State private var isDismissing = false

    @State private var isAtBottom = true
    @State private var canScroll = false
    @State private var isAtTop = true
    @State private var isStatusBarHidden = false
    @State private var noteReady = false

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

    init(note: Note, selectedNoteID: Binding<UUID?>, isPreview: Bool? = false) {
        self._selectedNoteID = selectedNoteID
        self._note = Bindable(wrappedValue: note)
        self.isPreview = isPreview

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
                isPreview: isPreview == true,
                text: $noteText,
                selectedRange: $selectedRange,
                note: note,
                keyboard: keyboard,
                onCoordinatorReady: { coordinator in
                    coordinatorHolder.coordinator = coordinator
                },
                isAtBottom: $isAtBottom,
                canScroll: $canScroll,
                isAtTop: $isAtTop,
                isNewNoteSwipeGesture: $isDragging,
                isDismissSwipeGesture: $isDismissing,
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
                coordinatorHolder.coordinator?.parseAttributedText(newValue)
            }
            .onChange(of: coordinatorHolder.coordinator?.paragraphs) { oldParagraphs, newParagraphs in
                // Handle changes in paragraphs, e.g., update UI based on spatial properties
                // print("Paragraphs changed: \(newParagraphs?.count ?? 0) paragraphs")
                // You can now access newParagraphs[i].height, newParagraphs[i].screenPosition, etc.
            }
            // .onTapGesture(count: 3) {
            //     let rtfdData = note.content
            //     let base64String = rtfdData.base64EncodedString()
            //     print("--- RTFD Base64 Start ---")
            //     print(base64String)
            //     print("--- RTFD Base64 End ---")
            // }

            if settings.newNoteIndicatorGestureEnabled {
                NewNoteIndicatorView(
                    translation: dragOffset,
                    location: dragLocation,
                    isDragging: isDragging,
                    dragActivationPoint: dragActivationPoint,
                )
            }

            if settings.dismissNoteGestureEnabled {
                DismissNoteIndicatorView(
                    translation: dismissDragOffset,
                    location: dismissDragLocation,
                    isDragging: isDismissing,
                    dragActivationPoint: dragActivationPoint,
                )
            }

            if isPreview != true {
                VStack {
                    HStack {
                        ScrollToTopButton(
                            action: { coordinatorHolder.coordinator?.scrollToTop() },
                            isAtTop: isAtTop,
                            canScroll: canScroll,
                        )
                        .padding(16)

                        Spacer()

                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title)
                                .foregroundColor(.gray)
                                .padding()
                                .opacity(0.5)
                        }
                        .glassEffectIfAvailable()
                        .padding(16)
                    }
                    Spacer()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .global)
                .onChanged { value in
                    let screenWidth = UIScreen.main.bounds.width
                    let startX = value.startLocation.x

                    // Edge detection: within 15pt from edges
                    let rightEdgeActive = settings.newNoteIndicatorGestureEnabled &&
                                        startX > screenWidth - 15

                    let leftEdgeActive = settings.dismissNoteGestureEnabled &&
                                       startX < 15

                    // Ensure mutual exclusivity - only one gesture at a time
                    if rightEdgeActive && !isDismissing {
                        dragOffset = value.translation
                        dragLocation = value.location
                        if !isDragging {
                            isDragging = true
                        }
                    } else if !isDragging {
                        isDragging = false
                        dragOffset = .zero
                        dragLocation = .zero
                    }

                    if leftEdgeActive && !isDragging {
                        dismissDragOffset = value.translation
                        dismissDragLocation = value.location
                        if !isDismissing {
                            isDismissing = true
                        }
                    } else if !isDismissing {
                        isDismissing = false
                        dismissDragOffset = .zero
                        dismissDragLocation = .zero
                    }
                }
                .onEnded { value in
                    // Handle right edge gesture
                    if isDragging, value.translation.width < -dragActivationPoint {
                        let newNote = Note()
                        context.insert(newNote)
                        selectedNoteID = newNote.id
                    }

                    // Handle left edge gesture
                    if isDismissing, value.translation.width > dragActivationPoint {
                        dismiss()
                    }

                    // Reset all drag states
                    isDragging = false
                    dragOffset = .zero
                    dragLocation = .zero
                    isDismissing = false
                    dismissDragOffset = .zero
                    dismissDragLocation = .zero
                }
        )
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .overlay(
            EditorToolbarOverlay(
                isPreview: isPreview == true,
                keyboard: keyboard,
                settings: settings,
                onBold: { coordinatorHolder.coordinator?.toggleAttribute(.bold) },
                onItalic: { coordinatorHolder.coordinator?.toggleAttribute(.italic) },
                onUnderline: { coordinatorHolder.coordinator?.toggleAttribute(.underline) },
                onTitle1: { coordinatorHolder.coordinator?.toggleAttribute(.title1) },
                onTitle2: { coordinatorHolder.coordinator?.toggleAttribute(.title2) },
                onBody: { coordinatorHolder.coordinator?.toggleAttribute(.body) },
                onScrollToBottom: {
                    coordinatorHolder.coordinator?.scrollToBottom()
                },
                isAtBottom: isAtBottom,
                canScroll: canScroll,
                isAtTop: isAtTop,
                onDismiss: {
                    dismiss()
                },
                onAddParagraph: {
                    coordinatorHolder.coordinator?.triggerReplyAction(fromButton: true)
                },
                hideKeyboard: {
                    coordinatorHolder.coordinator?.hideKeyboard()
                }
            )
        )
        .onAppear {
            isStatusBarHidden = true
            UserDefaults.standard.set(note.id.uuidString, forKey: "lastOpenedNoteID")
            noteReady = true
        }
        .onDisappear {
            isStatusBarHidden = false
            UserDefaults.standard.removeObject(forKey: "lastOpenedNoteID")
            noteReady = false
        }
        .statusBar(hidden: isStatusBarHidden)
        .opacity(noteReady ? 1 : 0)
        .animation(.easeInOut(duration: 0.75).delay(0.1), value: noteReady)
    }
}
