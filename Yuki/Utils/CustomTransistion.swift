//
//  CustomTransistion.swift
//  Yuki
//
//  Created by Daniel Inama on 12/3/25.
//

import SwiftUI

// Custom transition for smooth workspace selection
extension AnyTransition {
    static var moveAndFade: AnyTransition {
        let insertion = AnyTransition.opacity.combined(with: .move(edge: .top))
        let removal = AnyTransition.opacity.combined(with: .move(edge: .bottom))
        return .asymmetric(insertion: insertion, removal: removal)
    }
}
