//
//  GlassEffectModifier.swift
//  notes2
//
//  Created by Lucio Cuddeford on 13/08/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.glassEffect()
    }
}

struct AnyVersionGlassEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.modifier(GlassEffectModifier())
        } else {
            content
        }
    }
}

extension View {
    func glassEffectIfAvailable() -> some View {
        modifier(AnyVersionGlassEffect())
    }
}
