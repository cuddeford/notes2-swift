//
//  EasingFunctions.swift
//  notes2
//
//  Created by Claude on 22/07/2025.
//

import Foundation

struct EasingFunctions {
    // MARK: - Cubic Functions
    static func easeInCubic(_ t: CGFloat) -> CGFloat {
        return t * t * t
    }
    
    static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        return 1 - pow(1 - t, 3)
    }
    
    static func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
    
    // MARK: - Quadratic Functions
    static func easeInQuad(_ t: CGFloat) -> CGFloat {
        return t * t
    }
    
    static func easeOutQuad(_ t: CGFloat) -> CGFloat {
        return t * (2 - t)
    }
    
    static func easeInOutQuad(_ t: CGFloat) -> CGFloat {
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
    
    // MARK: - Sine Functions
    static func easeInSine(_ t: CGFloat) -> CGFloat {
        return 1 - cos((t * CGFloat.pi) / 2)
    }
    
    static func easeOutSine(_ t: CGFloat) -> CGFloat {
        return sin((t * CGFloat.pi) / 2)
    }
    
    static func easeInOutSine(_ t: CGFloat) -> CGFloat {
        return -(cos(CGFloat.pi * t) - 1) / 2
    }
    
    // MARK: - Exponential Functions
    static func easeInExpo(_ t: CGFloat) -> CGFloat {
        return t == 0 ? 0 : pow(2, 10 * t - 10)
    }
    
    static func easeOutExpo(_ t: CGFloat) -> CGFloat {
        return t == 1 ? 1 : 1 - pow(2, -10 * t)
    }
    
    static func easeInOutExpo(_ t: CGFloat) -> CGFloat {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        return t < 0.5 ? pow(2, 20 * t - 10) / 2 : (2 - pow(2, -20 * t + 10)) / 2
    }
    
    // MARK: - Back Functions
    static func easeInBack(_ t: CGFloat) -> CGFloat {
        let c1 = 1.70158
        let c3 = c1 + 1
        return c3 * t * t * t - c1 * t * t
    }
    
    static func easeOutBack(_ t: CGFloat) -> CGFloat {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }
    
    static func easeInOutBack(_ t: CGFloat) -> CGFloat {
        let c1 = 1.70158
        let c2 = c1 * 1.525
        return t < 0.5
            ? (pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
            : (pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
    }
    
    // MARK: - CSS Cubic Bezier
    static func cssCubicBezier(_ t: CGFloat, _ p1x: CGFloat, _ p1y: CGFloat, _ p2x: CGFloat, _ p2y: CGFloat) -> CGFloat {
        // CSS cubic-bezier timing function implementation
        // p1x, p1y, p2x, p2y are the control points (like CSS cubic-bezier(p1x, p1y, p2x, p2y))
        
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        
        // Newton's method to find t for given x
        func getTForX(_ x: CGFloat) -> CGFloat {
            var t2 = x
            for _ in 0..<4 {
                let x2 = bezierPoint(t2, 0, p1x, p2x, 1) - x
                if abs(x2) < 1e-6 { break }
                let dx = bezierDerivative(t2, 0, p1x, p2x, 1)
                if abs(dx) < 1e-6 { break }
                t2 = t2 - x2 / dx
            }
            return t2
        }
        
        let t2 = getTForX(t)
        return bezierPoint(t2, 0, p1y, p2y, 1)
    }
    
    // MARK: - Bezier Helpers
    private static func bezierPoint(_ t: CGFloat, _ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat) -> CGFloat {
        let mt = 1 - t
        return mt * mt * mt * p0 + 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t * p3
    }
    
    private static func bezierDerivative(_ t: CGFloat, _ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat) -> CGFloat {
        let mt = 1 - t
        return 3 * mt * mt * (p1 - p0) + 6 * mt * t * (p2 - p1) + 3 * t * t * (p3 - p2)
    }
}