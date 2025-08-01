import SwiftUI

struct SettingsView: View {
    @AppStorage("recentsVisible") private var recentsVisible = true
    @AppStorage("historyVisible") private var historyVisible = true
    @AppStorage("pinnedVisible") private var pinnedVisible = true
    @AppStorage("newNoteWithBigFont") private var newNoteWithBigFont = true

    var body: some View {
        Form {
            Section(header: Text("Show Sections")) {
                Toggle("Pinned", isOn: $pinnedVisible)
                Toggle("Recents", isOn: $recentsVisible)
                Toggle("History", isOn: $historyVisible)
            }

            Section(header: Text("Editor")) {
                Toggle("Magnetic Scrolling", isOn: Binding(
                    get: { AppSettings.shared.magneticScrollingEnabled },
                    set: { AppSettings.shared.magneticScrollingEnabled = $0 }
                ))
                Toggle("New Notes Start with Big Font", isOn: $newNoteWithBigFont)
                Toggle("Drag to Reorder Paragraphs (WIP)", isOn: Binding(
                    get: { AppSettings.shared.dragToReorderParagraphEnabled },
                    set: { AppSettings.shared.dragToReorderParagraphEnabled = $0 }
                ))
            }
        }
        .navigationTitle("Settings")
    }
}
