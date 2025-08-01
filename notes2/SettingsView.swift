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
                    if settings.defaultParagraphSpacing == AppSettings.relatedParagraphSpacing {
                        Text("Paragraphs default to: ") + Text("Related").fontWeight(.bold)
                    } else {
                        Text("Paragraphs default to: ") + Text("Unrelated").fontWeight(.bold)
                    }
                }
                Toggle("Magnetic Scrolling", isOn: $settings.magneticScrollingEnabled)
                Toggle("New Notes Start with Big Font", isOn: $newNoteWithBigFont)
                Toggle("Drag to Reorder Paragraphs (WIP)", isOn: $settings.dragToReorderParagraphEnabled)
                Toggle("Enable paragraph overlays", isOn: $settings.paragraphOverlaysEnabled)
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
