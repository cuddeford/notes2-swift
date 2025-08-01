import SwiftUI

struct SettingsView: View {
    @AppStorage("recentsVisible") private var recentsVisible: Bool
    @AppStorage("historyVisible") private var historyVisible: Bool
    @AppStorage("pinnedVisible") private var pinnedVisible: Bool
    @AppStorage("newNoteWithBigFont") private var newNoteWithBigFont: Bool

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
