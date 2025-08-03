# Refactoring `RichTextEditor.swift`

## Introduction

The `RichTextEditor.swift` file currently encompasses a significant amount of logic within its `Coordinator` class, handling text parsing, UI updates, various gestures (pinch, drag-to-reorder, swipe-to-reply/delete), animations, and haptic feedback. This monolithic structure leads to reduced readability, maintainability, and testability.

## Goals of Refactoring

The primary goals of this refactoring effort are to:

1.  **Improve Readability and Maintainability:** By breaking down the large `Coordinator` into smaller, focused units, the codebase will become easier to understand and navigate.
2.  **Enhance Testability:** Decoupling concerns will allow for more isolated and effective unit testing of individual components.
3.  **Reduce Complexity:** Distribute responsibilities across specialized classes, reducing the cognitive load associated with any single file or type.
4.  **Adhere to Idiomatic Apple Engineering Practices:** Embrace principles like separation of concerns, protocol-oriented programming, and the use of extensions to organize code in a way that is familiar and efficient for Swift/UIKit/SwiftUI developers.

## Proposed Refactoring Strategy

The core of this refactoring involves extracting distinct functionalities from the `RichTextEditor.Coordinator` into dedicated manager classes or helper structs. The `Coordinator` will then act as a central orchestrator, delegating tasks to these specialized components.

### Proposed File Structure

To support this refactoring, we will introduce a new subdirectory `notes2/RichTextEditor/` to house the extracted components.

```
notes2/
├───RichTextEditor.swift             // Main UIViewRepresentable
├───RichTextEditorCoordinator.swift  // The main Coordinator, now delegating tasks
├───RichTextEditor/
│   ├───Managers/
│   │   ├───ParagraphManager.swift
│   │   ├───TextStylingManager.swift
│   │   ├───PinchGestureHandler.swift
│   │   ├───DragToReorderHandler.swift
│   │   ├───SwipeToReplyDeleteHandler.swift
│   │   └───ScrollingManager.swift
│   ├───Models/
│   │   └───ActiveAnimation.swift
│   ├───Views/
│   │   └───CustomTextView.swift
│   └───Extensions/
│       ├───UIFont+NoteStyle.swift
│       ├───NSAttributedString+Helpers.swift
│       └───UITextView+Helpers.swift
```

### Component Breakdown and Responsibilities

#### 1. `RichTextEditor.swift` (Existing)

*   **Responsibility:** Remains the `UIViewRepresentable` wrapper for `CustomTextView`.
*   **Content:** `RichTextEditor` struct, `makeUIView`, `updateUIView`, `makeCoordinator`.
*   **Changes:** `updateUIView` will primarily focus on updating the `CustomTextView` and passing relevant data to the `Coordinator`. Gesture recognizers will still be added here, but their targets will be the `Coordinator` which then delegates to the respective handlers.

#### 2. `RichTextEditorCoordinator.swift` (New/Refactored)

*   **Responsibility:** Acts as the `UITextViewDelegate` and orchestrates interactions between the `RichTextEditor` (parent) and the new manager classes. It will hold instances of the managers and delegate calls to them. It will also manage the `@Published` properties that represent the overall state of the editor (e.g., `paragraphs`, `contentOffset`, `textViewWidth`, `isAtBottom`, `canScroll`, `isAtTop`).
*   **Content:** The `Coordinator` class, its `init`, and the `UITextViewDelegate` methods (`textViewDidChange`, `textViewDidChangeSelection`, `scrollViewDidScroll`, `scrollViewWillBeginDragging`, `scrollViewDidEndDecelerating`, `scrollViewDidEndDragging`).
*   **Changes:** Most of the current logic within the `Coordinator` will be moved to the new manager classes. The `Coordinator` will primarily call methods on its manager instances, acting as a central hub for data flow and event handling. It will also be responsible for updating the `parent`'s `@Binding` properties based on information received from the managers.

#### 3. `ParagraphManager.swift` (New)

*   **Responsibility:** Handles all logic related to parsing attributed text into `Paragraph` objects, managing the `paragraphs` array, updating spatial properties of paragraphs, and reconstructing the attributed text from the `paragraphs` array. This manager will be the single source of truth for the `paragraphs` array.
*   **Methods to Extract:**
    *   `parseAttributedText(_:)`
    *   `updateParagraphSpatialProperties()`
    *   `reconstructAttributedText()`
    *   `animateNewParagraphSpacing(cursorLocation:)` (This involves paragraph state, so it fits here)
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`. It will expose methods for other managers/coordinator to request updates to the `paragraphs` array or retrieve its current state.

#### 4. `TextStylingManager.swift` (New)

*   **Responsibility:** Manages the application and toggling of text attributes (bold, italic, underline, title styles).
*   **Methods to Extract:**
    *   `toggleAttribute(_:)`
*   **Dependencies:** `textView` (to access `attributedText`, `selectedRange`, `typingAttributes`).
*   **Helper Functions:** `paragraphRange(for:at:)` and `wordRange(for:at:)` should be moved to `NSAttributedString+Helpers.swift` or `UITextView+Helpers.swift`.

#### 5. `PinchGestureHandler.swift` (New)

*   **Responsibility:** Encapsulates all logic for the pinch gesture, including gesture recognition, calculating spacing, applying haptics, and managing spacing animations. All state variables related to the pinch gesture (e.g., `isPinching`, `initialPinchDistance`, `activePinchedPairs`, `pinchedParagraphIndices`, `currentDetent`, `hapticGenerator`s, `spacingDetents`, `activeAnimations`) will move into this class.
*   **Methods to Extract:**
    *   `handlePinchGesture(_:)` (the `@objc` method called by `UIPinchGestureRecognizer`)
    *   `handlePinchBegan(_:textView:)`
    *   `handlePinchChanged(_:textView:)`
    *   `handlePinchEnded(_:textView:)`
    *   `startSpacingAnimation(from:to:range:)`
    *   `updateSpacingAnimation(_:)`
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`. It will communicate changes in paragraph spacing back to the `Coordinator` (or `ParagraphManager`) so the `NSAttributedString` can be updated.
*   **Models:** `ActiveAnimation` struct should be moved to `notes2/RichTextEditor/Models/ActiveAnimation.swift`.

#### 6. `DragToReorderHandler.swift` (New)

*   **Responsibility:** Manages the long-press gesture for drag-to-reorder functionality, including ghost view creation, auto-scrolling, and haptic feedback. All state variables related to drag-to-reorder (e.g., `draggingParagraphIndex`, `dragGhostView`, `dragInitialLocation`, `dragTargetIndex`, `draggedParagraphID`, `isDragging`, `scrollDisplayLink`, `isAutoScrolling`) will move into this class.
*   **Methods to Extract:**
    *   `handleLongPressGesture(_:)` (the `@objc` method called by `UILongPressGestureRecognizer`)
    *   `handleDragBegan(location:textView:gesture:)`
    *   `handleDragChanged(location:textView:gesture:)`
    *   `handleDragEnded(location:textView:gesture:)`
    *   `paragraphIndex(at:textView:)`
    *   `createDragGhost(for:at:textView:)`
    *   `calculateTargetIndex(for:textView:)`
    *   `setDraggingSource(_:)`
    *   `cancelDrag()`
    *   `cleanupDrag()`
    *   `startAutoScroll()`
    *   `stopAutoScroll()`
    *   `updateAutoScroll()`
    *   `checkAutoScroll(location:textView:)`
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`. This handler will *propose* paragraph reorders (e.g., `sourceIndex`, `targetIndex`) back to the `Coordinator`, which will then instruct the `ParagraphManager` to perform the actual reordering and update the `NSAttributedString`.

#### 7. `SwipeToReplyDeleteHandler.swift` (New)

*   **Responsibility:** Manages the pan gesture for swipe-to-reply and swipe-to-delete actions, including ghost views, overlay indicators, hold-to-confirm logic, and triggering the respective actions. All state variables related to swipe gestures (e.g., `replyGestureParagraphIndex`, `replyGhostView`, `replyOverlayView`, `replyGestureInitialLocation`, `isHorizontalSwipe`, `swipeDirection`, `holdStartTime`, `isHolding`, `holdProgressView`, `holdDisplayLink`) will move into this class.
*   **Methods to Extract:**
    *   `handleSwipeToReplyGesture(_:)` (the `@objc` method called by `UIPanGestureRecognizer`)
    *   `handleReplyGestureBegan(location:textView:)`
    *   `handleReplyGestureChanged(gesture:textView:)`
    *   `handleReplyGestureEnded(gesture:textView:)`
    *   `createReplyGhost(for:at:textView:)`
    *   `createCircularProgressView()`
    *   `createReplyOverlay(for:at:textView:)`
    *   `updateHoldProgress()`
    *   `cleanupReplyGesture()`
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`. This handler will *trigger* reply or delete actions (e.g., `triggerReplyAction(forParagraphIndex:)`, `triggerDeleteAction(forParagraphIndex:)`) back to the `Coordinator`, which will then handle the actual text modification via the `ParagraphManager`.
*   **Enums:** `SwipeDirection` enum should be moved here.

#### 8. `ScrollingManager.swift` (New)

*   **Responsibility:** Handles all scrolling-related logic, including typewriter mode, magnetic scrolling, and scroll-to-top/bottom functionality. All state variables related to scrolling (e.g., `currentMagneticParagraph`, `selectionHapticGenerator`, `isUserDragging`) will move into this class.
*   **Methods to Extract:**
    *   `centerCursorInTextView()`
    *   `findParagraphToSnap()`
    *   `findCenteredParagraph()`
    *   `checkMagneticZoneTransition()`
    *   `applyMagneticSnap(to:)`
    *   `scrollToBottom()`
    *   `scrollToTop()`
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`. It will also need a mechanism (e.g., a delegate protocol or closure) to inform the `Coordinator` about changes to `isAtBottom`, `canScroll`, and `isAtTop`.

#### 9. `CustomTextView.swift` (New File)

*   **Responsibility:** This file will contain the `CustomTextView` class definition, which is a subclass of `UITextView`. It includes custom properties like `weak var coordinator: Coordinator?` and any overrides for `UITextView` behavior (e.g., custom caret handling, paste behavior).
*   **Content:** The `CustomTextView` class definition.

#### 10. `ActiveAnimation.swift` (New File)

*   **Responsibility:** A simple struct to hold the state of an active animation.
*   **Content:** The `ActiveAnimation` struct definition.

#### 11. Extensions (New Files)

*   **`UIFont+NoteStyle.swift`:** For the `noteStyle` and `withToggledTrait` methods.
*   **`NSAttributedString+Helpers.swift`:** For utility methods like `paragraphRange(for:at:)` and `wordRange(for:at:)`. These are general utility functions that operate on `NSAttributedString` and are not specific to the editor's core logic.
*   **`UITextView+Helpers.swift`:** For any utility methods directly on `UITextView` that are not specific to the editor's core logic.

## Implementation Details and Considerations

*   **Delegation Pattern:** The `RichTextEditorCoordinator` will instantiate each manager class and pass necessary dependencies (like `textView`, `ruledView`, `parent.settings`) to their initializers. For interactions where a manager needs to inform the `Coordinator` about an event or a proposed change (e.g., a gesture handler completing an action that requires updating `parent.text`), define simple protocols (e.g., `PinchGestureHandlerDelegate`, `DragToReorderHandlerDelegate`, `SwipeToReplyDeleteHandlerDelegate`, `ScrollingManagerDelegate`). The `Coordinator` will conform to these protocols and implement the necessary callback methods.

*   **Dependency Injection:** Explicitly pass all required dependencies to the initializers of the manager classes. This makes the dependencies clear and facilitates easier testing. For example:
    ```swift
    class PinchGestureHandler {
        weak var textView: UITextView?
        weak var ruledView: RuledView?
        var settings: AppSettings

        init(textView: UITextView, ruledView: RuledView, settings: AppSettings, delegate: PinchGestureHandlerDelegate) {
            self.textView = textView
            self.ruledView = ruledView
            self.settings = settings
            self.delegate = delegate // Assuming a delegate property
        }
    }
    ```

*   **Weak References:** Ensure that strong reference cycles are avoided, especially when passing `textView` or `ruledView` to managers. Use `weak` or `unowned` where appropriate to prevent retain cycles.

*   **State Management:** Carefully consider which state variables belong to the `Coordinator` and which belong to the individual managers. Generally, state directly related to a manager's responsibility should reside within that manager. The `Coordinator` will maintain the overall editor state (e.g., the `paragraphs` array, `selectedRange`, `contentOffset`) and act as the central point for updating the `UIViewRepresentable`'s `@Binding` properties.

*   **Testing:** After refactoring, each manager class can be instantiated and tested independently, mocking its dependencies (e.g., `UITextView`, `RuledView`) to ensure its logic is correct. This significantly improves the testability of the codebase.

*   **Private vs. Public/Internal:** Ensure that methods and properties within managers are appropriately scoped. Internal helper methods should be `private`. Methods that are part of the public API of a manager (i.e., called by the `Coordinator`) should be `internal` or `public` as appropriate.

This refactoring will significantly improve the modularity and maintainability of the `RichTextEditor` component, making future development and debugging much more efficient.
