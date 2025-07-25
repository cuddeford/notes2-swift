### How should Gemini behave?

You do not apologise. You do not tell me I am right. You are succinct, straightforward, and matter of fact. We are solving technical challenges together and I value efficiency over prose. After a significant feature, fix, or refactor you re-read and update GEMINI.md to bring it up to date and remove obsolete parts.

### Project description

This is a simple, distraction-free notes app for iOS and iPadOS, written in Swift and SwiftUI.

### Project Structure

The source folder is notes2/ so e.g. notes2/RichTextEditor.swift

When building the project to test compilation use this command. It's important to keep the -quiet flag to save on input tokens:
```
xcodebuild -quiet -project notes2.xcodeproj -scheme notes2 -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build)
```

*   **`notes2App.swift`**: The main entry point of the application. It sets up the main window and the SwiftData model container for the `Note` object, configured for iCloud synchronization using a specific app group.
*   **`ContentView.swift`**: The main view of the app. It displays a list of notes, grouped by creation date (Today, Yesterday, etc.), and provides navigation to individual note views. It also features collapsible sections for "Pinned" and "Recent" notes. It handles a right-to-left swipe gesture to quickly navigate to the last edited note.
*   **`Note.swift` (`@Model`)**: The SwiftData model for a single note. It includes properties for the note's content (stored as RTFD data), creation/update timestamps, cursor position, and a flag for pinning. The `firstLine` computed property truncates the note's first line to 70 characters.
*   **`NoteView.swift`**: The view for editing a single note. It uses a `RichTextEditor` to allow for formatted text and handles a right-to-left swipe gesture to create a new note. It observes paragraph data from the editor to manage layout.
*   **`RichTextEditor.swift`**: A `UIViewRepresentable` that wraps a `UITextView` to provide a rich text editing experience. It handles text styling, manages the keyboard and cursor, and implements typewriter scrolling. It uses a `Paragraph` data structure internally and handles a pinch gesture between two adjacent paragraphs to adjust their spacing. To handle overlapping gestures, it stores a timestamp with each pinched pair to ensure the most recent gesture's state is used for visual feedback.
*   **`Paragraph.swift`**: A data structure representing a paragraph, holding its content, range, style, and spatial properties like height and on-screen position.
*   **`RuledView.swift`**: A `UIView` subclass used by `RichTextEditor` to draw visual overlays for the paragraph spacing gesture. It has been updated to use timestamps to correctly render visual feedback for paragraph relationships, even when gestures overlap.
*   **`EditorToolbar.swift`**: A SwiftUI view that provides a collapsible toolbar with buttons for text formatting (bold, italic, underline, headings). It's displayed above the keyboard when editing a note.
*   **`EditorToolbarOverlay.swift`**: A SwiftUI view that acts as an overlay for `RichTextEditor`, dynamically positioning the `EditorToolbar` above the keyboard and handling its presentation.
*   **`NoteRow.swift`**: A SwiftUI view for displaying a single note in the main list. It handles swipe actions for pinning and deleting notes.
*   **`KeyboardObserver.swift`**: A helper class that observes keyboard visibility and height changes, allowing the UI to adjust accordingly.
*   **`Date+Helpers.swift`**: An extension on `Date` to provide formatted and relative date strings (e.g., "Today", "Yesterday", "Last Wednesday").
*   **`FontStyleHelper.swift`**: An extension on `UIFont` to provide custom font styles for the notes.
*   **`Config.swift`**: A class to manage application-wide settings, such as padding, paragraph spacing, and font size, using `@AppStorage` to persist them.
*   **`UINavigationController+SwipeBack.swift`**: An extension to re-enable the default swipe-back gesture for navigation.
*   **`URL+Helpers.swift`**: Provides a helper function to construct the `storeURL` for SwiftData, supporting app groups for shared data.
*   **`LastNoteIndicatorView.swift`**: A SwiftUI view that displays a visual indicator for the "Go to Last Edited Note" swipe gesture, showing the first line of the target note.
*   **`NewNoteIndicatorView.swift`**: A SwiftUI view that displays a visual indicator for the "New Note" swipe gesture.
*   **`EasingFunctions.swift`**: A utility struct providing a collection of easing functions for animations.

### Key Features

*   **Rich Text Editing**: Users can format their notes with bold, italic, underline, and different heading styles.
*   **Typewriter Mode**: Keeps the current line of text in a comfortable reading position while typing.
*   **Note Organization**: Notes are automatically grouped by date in collapsible sections.
*   **Pinned Notes**: Users can pin important notes to the top of the list.
*   **Recent Notes**: The two most recently updated notes are shown in a dedicated section.
*   **Distraction-Free Writing**: The UI is designed to be minimal and focus on the content.
*   **SwiftData Integration**: The app uses SwiftData for local data persistence.
*   **iCloud Sync**: Notes sync seamlessly across a user's devices using SwiftData and CloudKit.
*   **Swipe to New Note**: A right-to-left swipe gesture from the right edge of `NoteView` allows for quick creation of a new note.
*   **Swipe to Last Edited Note**: A right-to-left swipe gesture from the right edge of `ContentView` allows for quick navigation to the most recently edited note.
*   **Paragraph Spacing Gesture**: Users can adjust the spacing between adjacent paragraphs using a pinch gesture, with visual feedback. The gesture logic correctly handles multiple, overlapping gestures.
*   **Animated New Paragraph Spacing**: When creating a new paragraph (by pressing Enter), the spacing animates.

### Last Reviewed

2025-07-25 02:58:00
