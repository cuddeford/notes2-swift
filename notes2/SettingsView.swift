import SwiftUI

struct SettingsView: View {
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
            Section(header: Text("Editor")) {
                Toggle(isOn: isDefaultSpacingRelated) {
                    Text("Paragraphs default to: ") + Text(settings.defaultParagraphSpacing == AppSettings.relatedParagraphSpacing ? "Related" : "Unrelated").fontWeight(.bold)
                }
                Text("This controls the default spacing between paragraphs when you create a new note or reset spacing.")
                    .font(.caption)
                    .foregroundColor(.gray)
                Toggle("Magnetic Scrolling", isOn: $settings.magneticScrollingEnabled)
                Text("Enables a feature that snaps the current line to the center of the screen while typing.")
                    .font(.caption)
                    .foregroundColor(.gray)
                Toggle("New Notes Start with Big Font", isOn: $newNoteWithBigFont)
                Text("When enabled, new notes will begin with a larger default font size.")
                    .font(.caption)
                    .foregroundColor(.gray)
                Toggle("Drag to Reorder Paragraphs (WIP)", isOn: $settings.dragToReorderParagraphEnabled)
                Text("Allows you to reorder paragraphs by long-pressing and dragging them. (Work in Progress)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Toggle("Enable paragraph overlays", isOn: $settings.paragraphOverlaysEnabled)
                Text("Shows visual boundaries around paragraphs. Overlays are always visible during gestures.")
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
    }
}
