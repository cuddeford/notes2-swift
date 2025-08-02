### How should Gemini behave?

You do not apologise. You do not tell me I am right. You are succinct, straightforward, and matter of fact. We are solving technical challenges together and I value efficiency over prose. After a significant feature, fix, or refactor you re-read and update GEMINI.md to bring it up to date and remove obsolete parts.

### Project description

This is a simple, distraction-free notes app for iOS and iPadOS, written in Swift and SwiftUI. It uses native SwiftUI List selection with a composite tag system to handle duplicate notes across sections while preserving all native styling.

### Project Structure

The source folder is notes2/ so e.g. notes2/RichTextEditor.swift

When building the project to test compilation use this command. It's important to keep the -quiet flag to save on input tokens:
```
xcodebuild -quiet -project notes2.xcodeproj -scheme notes2 -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Whenever I tell you to build, run, or compile the project I expect you to use this exact command ^

### Core Architecture

**Data Model:**
- `Note.swift` (@Model): SwiftData model storing RTFD content, timestamps, cursor position, pin status
- Uses iCloud sync via SwiftData + CloudKit with app group configuration

**Navigation Pattern:**
- `ContentView.swift`: Uses composite tag system with `List(selection:)`
- Tags format: `"section-{noteID}"` (e.g., "pinned-12345", "recents-12345", "history-12345")
- Maps composite selection back to actual note IDs for navigation

**Views by Responsibility:**

**Main Views:**
- `ContentView.swift`: Master list with Pinned, Recents, History sections. Uses composite tags for selection consistency
- `NoteView.swift`: Detail view for editing individual notes with typewriter mode

**Editing Components:**
- `RichTextEditor.swift`: UIViewRepresentable wrapping UITextView with coordinator pattern for rich text editing
  - **CustomTextView**: Subclass of UITextView with custom caret handling and paste behavior
  - **Editor Coordinator**: Manages text processing, gestures, animations, and state synchronization
- `EditorToolbar.swift`: Formatting toolbar with bold, italic, underline, and heading styles
- `EditorToolbarOverlay.swift`: Positions toolbar above keyboard with safe area handling

**Supporting Components:**
- `NoteRow.swift`: Single note display in lists with relative date formatting
- `Paragraph.swift`: Lightweight struct for paragraph-level operations with spatial properties
- `RuledView.swift`: Real-time paragraph visualization with semi-transparent overlays

**Animation & Utilities:**
- `EasingFunctions.swift`: Comprehensive easing library (cubic, quadratic, sine, exponential, back)
- `KeyboardObserver.swift`: Reactive keyboard height tracking with Combine
- `Date+Helpers.swift`: Relative date strings with ordinal suffixes ("1st", "2nd", "3rd")
- `Config.swift`: App-wide settings with @AppStorage persistence
- `URL+Helpers.swift`: SwiftData store URL construction with security-scoped URLs

**Gestures & Interactions:**
- **Pinch gesture**: Adjust paragraph spacing between adjacent paragraphs
- **Swipe right-to-left on NoteView**: Create new note
- **Swipe right-to-left on ContentView**: Navigate to last edited note
- **Swipe actions**: Pin/unpin and delete notes

**Utilities:**
- `KeyboardObserver.swift`: Keyboard visibility and height changes
- `Date+Helpers.swift`: Relative date strings ("Today", "Yesterday")
- `Config.swift`: App-wide settings with @AppStorage persistence
- `URL+Helpers.swift`: SwiftData store URL construction

### Selection System Details

**Composite Tag Pattern:**
```swift
.tag("pinned-\(note.id)")      // Pinned section
.tag("recents-\(note.id)")     // Recents section
.tag("history-\(note.id)")     // History section
```

**Selection Mapping:**
- List uses `selectedCompositeID: String?`
- Navigation uses `selectedNoteID: UUID?`
- Mapping: Extract UUID from `"section-uuid"` format

### Key Features

**Rich Text Editing:**
- **UIViewRepresentable Architecture**: Custom UITextView wrapper with coordinator pattern for rich text editing
- **Typewriter Mode**: Dynamic scrolling keeps current line centered during editing with 0.1s animations
- **RTFD Format**: Full rich text persistence with formatting, images, and cursor position
- **Three Style Levels**: Title1, Title2, Body with bold/italic/underline support
- **Smart Attribute Application**: Context-aware styling (selection/word/paragraph based)

**Note Organization:**
- **Pinned**: Manually pinned notes at top with pin/unpin swipe actions
- **Recents**: 2 most recently updated notes with automatic management
- **History**: Grouped by creation date (Today, Yesterday, Last week, etc.)

**Advanced Gesture System:**
- **Pinch Gesture**: Spatial recognition for adjusting paragraph spacing between adjacent paragraphs
  - Two detent system: Related (32pt) vs Unrelated (250pt) spacing
  - Haptic feedback: Heavy at limits, light during transitions
  - Visual feedback: Color-coded overlays (green=related, yellow=unrelated)
- **Magnetic Paragraph Scrolling**: Instagram Reels-style snap-to-top behavior
  - Selection haptics on zone enter/exit (100pt activation window)
  - Light haptic on snap initiation
  - Excludes first paragraph for free scrolling
  - Smooth spring animations with 0.3s duration
- **Swipe Gestures**:
  - **ContentView**: Right-to-left from edge navigates to last edited note
  - **NoteView**: Right-to-left swipe creates new note
  - **Swipe actions**: Pin/unpin and delete notes with confirmation
- **Drag System**: Custom overlay indicators with 60fps animations
- **Drag-to-Reorder**: Long-press to drag paragraphs with ghost overlay and target indicators
  - **Ghost Technique**: Original paragraph fades to 30% opacity with floating ghost overlay
  - **Target Indicators**: Blue highlighted zones between paragraphs show drop locations
  - **Multitouch Support**: One finger holds paragraph, second finger scrolls
  - **Smooth Animations**: 0.2s fade transitions for visual feedback
  - **Haptic Feedback**: Light impact on drop, selection feedback on target changes

**Visual System:**
- **RuledView**: Real-time paragraph visualization with semi-transparent overlays
- **Dynamic Styling**: Color changes based on paragraph relationships during interactions
- **Haptic Border Effects**: Temporary border thickness changes during gestures
- **Dark Mode**: Automatic color adjustment for system theme changes

**Technical Architecture:**
- **SwiftData + CloudKit**: Full iCloud sync with app group configuration
- **Native SwiftUI List**: Composite tag system with unique per-section identification
- **Performance Optimizations**: Layer reuse, debounced updates, selective redrawing
- **Memory Management**: Weak references to prevent retain cycles, proper cleanup systems
- **Responsive Layout**: Adaptive for iPhone/iPad with size class awareness
- **Multi-window Support**: Scene-based architecture with state restoration

### Advanced Architecture Details

**Animation Framework:**
- **Easing Functions**: Comprehensive library with cubic, quadratic, sine, exponential, and back easing
- **CADisplayLink**: 60fps animations for gesture feedback and spacing changes
- **Spring Animations**: Interactive spring animations for haptic feedback
- **Smooth Transitions**: 0.1s animations for cursor positioning and UI changes

**Performance Optimizations:**
- **Layer Reuse**: CAShapeLayer reuse in RuledView for optimal performance
- **Selective Updates**: Only redraw changed paragraphs during text processing
- **Debounced Processing**: Text parsing debounced to prevent excessive computation
- **Memory Management**: Weak references prevent retain cycles, proper cleanup systems
- **Lazy Loading**: Components initialized on-demand for optimal startup time

**Advanced Text Processing:**
- **Real-time Paragraph Parsing**: Text parsed into Paragraph objects on every change
- **Spatial Properties**: Each paragraph tracks screen position, height, and line count
- **Typewriter Mode**: Dynamic scrolling keeps cursor centered during editing
- **Smart Range Detection**: Automatic paragraph and word range detection
- **Safe Array Access**: Bounds-checked array operations prevent crashes

**Security & Privacy:**
- **iCloud Encryption**: Full CloudKit encryption for note content and metadata
- **App Sandboxing**: Proper entitlements and security-scoped URLs
- **Data Protection**: iCloud encryption handled by CloudKit's built-in mechanisms
- **Privacy by Design**: No third-party analytics or data collection

**iPad-specific Features:**
- **NavigationSplitView**: Automatic sidebar collapse in landscape orientation
- **Multi-window Support**: Scene-based architecture with full state restoration
- **External Display**: Responsive to external display changes and orientations
- **Size Class Awareness**: Different behaviors for compact vs regular size classes
- **Settings Integration**: Extended settings menu available in both portrait and landscape modes with toggles for:
  - Collapse sidebar in landscape
  - Collapse sidebar in portrait
  - Show/hide individual sections (Pinned, Recents, History)

### Development Tips

**Selection Issues:** When notes appear in multiple sections, use composite tags ("section-{noteID}") to ensure unique identification per section context while preserving native SwiftUI selection styling.

**Build Command:** Always use the exact xcodebuild command above for testing compilation. The -quiet flag is essential for token efficiency.

**Gesture Debugging:** Use the RuledView overlay system to visualize paragraph boundaries during pinch gesture development.

**Memory Leaks:** Monitor coordinator patterns and ensure proper cleanup in UIViewRepresentable implementations.

**File Structure:** All source files are in the notes2/ directory. Follow existing naming conventions and architectural patterns for consistency.

**Testing Tips:** Use iPad simulator in landscape for testing sidebar behavior, and iPhone simulator for testing compact layout adaptations.

### Last Updated
When generating this timestamp be sure to run `date "+%Y-%m-%d %H:%M:%S"` to get the actual date.

2025-07-25 22:51:18
