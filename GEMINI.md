### How should Gemini behave?
You do not apologise. You do not tell me I am right. You are succinct, straightforward, and matter of fact. We are solving technical challenges together and I value efficiency over prose. After a significant feature, fix, or refactor you re-read and update GEMINI.md to bring it up to date and remove obsolete parts.

### Project description

This is a simple, distraction-free notes app for iOS and iPadOS, written in Swift and SwiftUI.

### Project Structure

The source folder is notes2/ so e.g. notes2/RichTextEditor.swift

*   **`notes2App.swift`**: The main entry point of the application. It sets up the main window and the SwiftData model container for the `Note` object, configured for iCloud synchronization using an app group. It also contains logic for migrating existing local notes to the new iCloud store.
*   **`ContentView.swift`**: The main view of the app. It displays a list of notes, grouped by creation date (Today, Yesterday, etc.), and provides navigation to individual note views. It also features sections for "Pinned" and "Recent" notes. It handles the "Go to Last Edited Note" swipe gesture.
*   **`Note.swift` (`@Model`)**: The SwiftData model for a single note. It includes properties for the note's content (stored as RTFD data), creation/update timestamps, cursor position, and a flag for pinning. The `firstLine` computed property now truncates the string to 60 characters and appends "..." if it's longer. This file was extracted from `ContentView.swift`.
*   **`NoteView.swift`**: The view for editing a single note. It uses a `RichTextEditor` to allow for formatted text. It also handles the "New Note" swipe gesture. This file was extracted from `ContentView.swift`. It now observes the `paragraphs` array from `RichTextEditor.Coordinator` and displays a debug overlay with paragraph spatial properties.
*   **`RichTextEditor.swift`**: A `UIViewRepresentable` that wraps a `UITextView` to provide a rich text editing experience within SwiftUI. It handles text styling (bold, italic, underline, headings), manages the keyboard and cursor, and implements typewriter scrolling to keep the current line of text in focus. It now uses a `Paragraph` data structure internally to manage paragraph properties. It also handles a pinch gesture to adjust paragraph spacing, with visual feedback for "related" (green) and "unrelated" (yellow) paragraphs. This gesture is now restricted to only two adjacent paragraphs.
*   **`Paragraph.swift`**: A new data structure representing a paragraph, holding its content, range, and properties like `paragraphSpacing`, `numberOfLines`, `height`, and `screenPosition`.
*   **`EditorToolbar.swift`**: A SwiftUI view that provides a toolbar with buttons for text formatting. It's displayed above the keyboard when editing a note.
*   **`NoteRow.swift`**: A SwiftUI view that displays a single note in the main list, showing the first line of the note and its creation date. It also handles swipe actions for pinning and deleting notes.
*   **`KeyboardObserver.swift`**: A helper class that observes keyboard visibility and height changes, allowing the UI to adjust accordingly.
*   **`Date+Helpers.swift`**: An extension on the `Date` class to provide formatted and relative date strings (e.g., "Today", "Yesterday", "Last Wednesday").
*   **`FontStyleHelper.swift`**: An extension on `UIFont` to provide custom font styles for the notes.
*   **`Config.swift`**: A class to manage application-wide settings, such as padding, paragraph spacing, and font size, using `@AppStorage` to persist them.
*   **`UINavigationController+SwipeBack.swift`**: An extension to re-enable the swipe-back gesture for navigation.
*   **`URL+Helpers.swift`**: Provides a helper function to construct the `storeURL` for SwiftData, supporting app groups for shared data.
*   **`LastNoteIndicatorView.swift`**: A SwiftUI view that displays a visual indicator for the "Go to Last Edited Note" swipe gesture. It now dynamically displays the first line of the note it will navigate to. This file was extracted from `ContentView.swift`.
*   **`NewNoteIndicatorView.swift`**: A SwiftUI view that displays a visual indicator for the "New Note" swipe gesture. This file was extracted from `ContentView.swift` and re-added to `NoteView.swift` to ensure its visibility.
*   **`RuledView.swift`**: A `UIView` subclass used by `RichTextEditor` to draw ruled lines and visual overlays for the paragraph spacing gesture. It now displays "Unrelated paragraphs" text when the detent is set to 100.

### Key Features

*   **Rich Text Editing**: Users can format their notes with bold, italic, underline, and different heading styles.
*   **Typewriter Mode**: Keeps the current line of text in a comfortable reading position while typing.
*   **Note Organization**: Notes are automatically grouped by date.
*   **Pinned Notes**: Users can pin important notes to the top of the list.
*   **Recent Notes**: The two most recently updated notes are shown in a dedicated "Recents" section.
*   **Distraction-Free Writing**: The UI is designed to be minimal and focus on the content.
*   **SwiftData Integration**: The app uses SwiftData for local data persistence.
*   **iCloud Sync**: Notes sync seamlessly across a user's devices using SwiftData and CloudKit, with a migration path for existing local notes.
*   **Unified Navigation**: Uses `selectedNoteID` for consistent navigation across iPhone (using `NavigationStack`) and iPad (using `NavigationSplitView`), ensuring correct behavior for both explicit taps and programmatic navigation.
*   **Swipe to New Note**: A right-to-left swipe gesture from the right edge of `NoteView` allows for quick creation of a new note, with the editor automatically focused.
*   **Swipe to Last Edited Note**: A right-to-left swipe gesture from the right edge of `ContentView` allows for quick navigation to the most recently edited note, now displaying the note's first line.
*   **Keyboard Focus Management**: The `RichTextEditor` now correctly manages keyboard focus, ensuring the keyboard appears automatically when a new note is created or an existing note is opened.
*   **Paragraph Spacing Gesture**: Users can adjust the spacing between adjacent paragraphs using a pinch gesture, with visual feedback (green for "related", yellow for "unrelated" with text).
