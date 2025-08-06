import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings = AppSettings.shared
    @AppStorage("recentsVisible") private var recentsVisible = true
    @AppStorage("historyVisible") private var historyVisible = true
    @AppStorage("pinnedVisible") private var pinnedVisible = true
    @AppStorage("newNoteWithBigFont") private var newNoteWithBigFont = true

    private var isDefaultSpacingRelated: Binding<Bool> {
        Binding<Bool>(
            get: { settings.defaultParagraphSpacing == AppSettings.relatedParagraphSpacing },
            set: { isRelated in
                settings.defaultParagraphSpacing = isRelated ? AppSettings.relatedParagraphSpacing : AppSettings.unrelatedParagraphSpacing
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $newNoteWithBigFont) {
                    Text("Text size defaults to: ") + Text(newNoteWithBigFont ? "Big" : "Normal").fontWeight(.bold)
                }
            } header: {
               Text("Editor")
            } footer: {
                Text("When enabled, new notes will begin with a larger default font size. This can help to make your thoughts feel more immediate.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Toggle(isOn: isDefaultSpacingRelated) {
                    Text("Thoughts start: ") + Text(settings.defaultParagraphSpacing == AppSettings.relatedParagraphSpacing ? "Related" : "Unrelated").fontWeight(.bold)
                }
            } footer: {
                Text("Controls the default spacing between thoughts when you start a new note. Pinch two thoughts together or apart to mark them as related or unrelated.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Toggle("Thought bubbles", isOn: $settings.paragraphOverlaysEnabled)
            } footer: {
                Text("Shows visual boundaries around thoughts.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Toggle("Magnetic scrolling", isOn: $settings.magneticScrollingEnabled)
            } footer: {
                Text("Snap a thought to the top of the screen when scrolling.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Toggle("Create new note", isOn: $settings.newNoteIndicatorGestureEnabled)
            } header: {
               Text("Gestures")
            } footer: {
                Text("Swipe from right edge of screen inside a note to create a new note.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Toggle("Open last note", isOn: $settings.lastNoteIndicatorGestureEnabled)
            } footer: {
                Text("Swipe from right edge of screen on notes list to open most recent note.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Toggle("Drag to reorder thoughts", isOn: $settings.dragToReorderParagraphEnabled)
            } footer: {
                Text("Reorder thoughts by long-pressing and dragging them.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section(header: Text("Show Sections")) {
                Toggle("Pinned", isOn: $pinnedVisible)
                Toggle("Recents", isOn: $recentsVisible)
                Toggle("History", isOn: $historyVisible)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
