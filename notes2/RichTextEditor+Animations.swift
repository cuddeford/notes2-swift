import SwiftUI
import QuartzCore

struct ActiveAnimation {
    let displayLink: CADisplayLink
    let startTime: CFTimeInterval
    let startSpacing: CGFloat
    let targetSpacing: CGFloat
    let range: NSRange
}