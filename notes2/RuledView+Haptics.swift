import UIKit

struct HapticBorderState {
    let timestamp: CFTimeInterval
    let type: HapticType
}

enum HapticType {
    case heavy
    case light
}