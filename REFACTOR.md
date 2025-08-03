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
*   **Changes:** `updateUIView` will primarily focus on updating the `CustomTextView` and passing relevant data to the `Coordinator`.

#### 2. `RichTextEditorCoordinator.swift` (New/Refactored)

*   **Responsibility:** Acts as the `UITextViewDelegate` and orchestrates interactions between the `RichTextEditor` (parent) and the new manager classes. It will hold instances of the managers and delegate calls to them.
*   **Content:** The `Coordinator` class, its `init`, and the `UITextViewDelegate` methods (`textViewDidChange`, `textViewDidChangeSelection`, `scrollViewDidScroll`, `scrollViewWillBeginDragging`, `scrollViewDidEndDecelerating`, `scrollViewDidEndDragging`).
*   **Changes:** Most of the current logic within the `Coordinator` will be moved to the new manager classes. The `Coordinator` will primarily call methods on its manager instances.

#### 3. `ParagraphManager.swift` (New)

*   **Responsibility:** Handles all logic related to parsing attributed text into `Paragraph` objects, managing the `paragraphs` array, updating spatial properties of paragraphs, and reconstructing the attributed text from the `paragraphs` array.
*   **Methods to Extract:**
    *   `parseAttributedText(_:)`
    *   `updateParagraphSpatialProperties()`
    *   `reconstructAttributedText()`
    *   `animateNewParagraphSpacing(cursorLocation:)` (This involves paragraph state, so it fits here)
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`.

#### 4. `TextStylingManager.swift` (New)

*   **Responsibility:** Manages the application and toggling of text attributes (bold, italic, underline, title styles).
*   **Methods to Extract:**
    *   `toggleAttribute(_:)`
*   **Dependencies:** `textView`, `parent.text`, `parent.selectedRange`.
*   **Helper Functions:** `paragraphRange(for:at:)` and `wordRange(for:at:)` should be moved to `NSAttributedString+Helpers.swift` or `UITextView+Helpers.swift`.

#### 5. `PinchGestureHandler.swift` (New)

*   **Responsibility:** Encapsulates all logic for the pinch gesture, including gesture recognition, calculating spacing, applying haptics, and managing spacing animations.
*   **Methods to Extract:**
    *   `handlePinchGesture(_:)`
    *   `handlePinchBegan(_:textView:)`
    *   `handlePinchChanged(_:textView:)`
    *   `handlePinchEnded(_:textView:)`
    *   `startSpacingAnimation(from:to:range:)`
    *   `updateSpacingAnimation(_:)`
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`, `hapticGenerator`, `completionHapticGenerator`, `lightHapticGenerator`, `activeAnimations`, `activePinchedPairs`, `isPinching`, `initialPinchDistance`, `initialSpacing`, `affectedParagraphRange`, `spacingDetents`, `animationDuration`, `lastDetentIndex`, `lastClosestDetent`, `wasAtLimit`, `startedAtLimit`, `initialLimitValue`, `hasTriggeredLightHaptic`, `pinchedParagraphIndices`, `currentDetent`.
*   **Models:** `ActiveAnimation` struct should be moved to `notes2/RichTextEditor/Models/ActiveAnimation.swift`.

#### 6. `DragToReorderHandler.swift` (New)

*   **Responsibility:** Manages the long-press gesture for drag-to-reorder functionality, including ghost view creation, auto-scrolling, paragraph reordering, and haptic feedback.
*   **Methods to Extract:**
    *   `handleLongPressGesture(_:)`
    *   `handleDragBegan(location:textView:gesture:)`
    *   `handleDragChanged(location:textView:gesture:)`
    *   `handleDragEnded(location:textView:gesture:)`
    *   `paragraphIndex(at:textView:)`
    *   `createDragGhost(for:at:textView:)`
    *   `calculateTargetIndex(for:textView:)`
    *   `reorderParagraph(from:to:textView:isLiveDrag:)`
    *   `rebuildAttributedString(from:)`
    *   `setDraggingSource(_:)`
    *   `cancelDrag()`
    *   `cleanupDrag()`
    *   `startAutoScroll()`
    *   `stopAutoScroll()`
    *   `updateAutoScroll()`
    *   `checkAutoScroll(location:textView:)`
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`, `dragSelectionGenerator`, `dragHapticGenerator`, `draggingParagraphIndex`, `dragGhostView`, `dragInitialLocation`, `dragTargetIndex`, `draggedParagraphID`, `isDragging`, `showGhostOverlay`, `scrollDisplayLink`, `isAutoScrolling`, `scrollEdgeThreshold`, `maxScrollSpeed`, `minScrollSpeed`, `initialTouchCount`, `isMultitouchDrag`.

#### 7. `SwipeToReplyDeleteHandler.swift` (New)

*   **Responsibility:** Manages the pan gesture for swipe-to-reply and swipe-to-delete actions, including ghost views, overlay indicators, hold-to-confirm logic, and triggering the respective actions.
*   **Methods to Extract:**
    *   `handleSwipeToReplyGesture(_:)`
    *   `handleReplyGestureBegan(location:textView:)`
    *   `handleReplyGestureChanged(gesture:textView:)`
    *   `handleReplyGestureEnded(gesture:textView:)`
    *   `createReplyGhost(for:at:textView:)`
    *   `createCircularProgressView()`
    *   `createReplyOverlay(for:at:textView:)`
    *   `triggerReplyAction()`
    *   `triggerDeleteAction()`
    *   `cleanupReplyGesture()`
    *   `updateHoldProgress()`
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`, `replyGestureParagraphIndex`, `replyGhostView`, `replyOverlayView`, `replyGestureInitialLocation`, `replyGestureThreshold`, `replyGestureHapticGenerator`, `hasTriggeredReplyHaptic`, `isHorizontalSwipe`, `swipeDirection`, `holdStartTime`, `isHolding`, `holdProgress`, `holdDuration`, `holdHapticGenerator`, `holdProgressView`, `holdDisplayLink`.
*   **Enums:** `SwipeDirection` enum should be moved here.

#### 8. `ScrollingManager.swift` (New)

*   **Responsibility:** Handles all scrolling-related logic, including typewriter mode, magnetic scrolling, and scroll-to-top/bottom functionality.
*   **Methods to Extract:**
    *   `centerCursorInTextView()`
    *   `findParagraphToSnap()`
    *   `findCenteredParagraph()`
    *   `checkMagneticZoneTransition()`
    *   `applyMagneticSnap(to:)`
    *   `scrollToBottom()`
    *   `scrollToTop()`
*   **Dependencies:** `textView`, `ruledView`, `parent.settings`, `parent.isAtBottom`, `parent.canScroll`, `parent.isAtTop`, `isPinching`, `currentMagneticParagraph`, `selectionHapticGenerator`, `isUserDragging`.

#### 9. `CustomTextView.swift` (New File)

*   **Responsibility:** If `CustomTextView` has custom logic beyond a standard `UITextView` (e.g., the `coordinator` property), it should reside in its own file.
*   **Content:** The `CustomTextView` class definition.

#### 10. `ActiveAnimation.swift` (New File)

*   **Responsibility:** A simple struct to hold the state of an active animation.
*   **Content:** The `ActiveAnimation` struct definition.

#### 11. Extensions (New Files)

*   **`UIFont+NoteStyle.swift`:** For the `noteStyle` and `withToggledTrait` methods.
*   **`NSAttributedString+Helpers.swift`:** For utility methods like `paragraphRange(for:at:)` and `wordRange(for:at:)` if they are not already in `TextUtilities.swift`.
*   **`UITextView+Helpers.swift`:** For any utility methods directly on `UITextView` that are not specific to the editor's core logic.

## Implementation Details and Considerations

*   **Delegation Pattern:** The `RichTextEditorCoordinator` will instantiate each manager class and pass necessary dependencies (like `textView`, `ruledView`, `parent.settings`) to their initializers.
*   **Weak References:** Ensure that strong reference cycles are avoided, especially when passing `textView` or `ruledView` to managers. Use `weak` or `unowned` where appropriate.
*   **Protocols for Callbacks:** For interactions where a manager needs to inform the `Coordinator` (e.g., a gesture handler completing an action that requires updating `parent.text`), define simple protocols (e.g., `PinchGestureHandlerDelegate`) and have the `Coordinator` conform to them.
*   **State Management:** Carefully consider which state variables belong to the `Coordinator` and which belong to the individual managers. Generally, state directly related to a manager's responsibility should reside within that manager.
*   **Testing:** After refactoring, each manager class can be instantiated and tested independently, mocking its dependencies (e.g., `UITextView`, `RuledView`) to ensure its logic is correct.

This refactoring will significantly improve the modularity and maintainability of the `RichTextEditor` component, making future development and debugging much more efficient.