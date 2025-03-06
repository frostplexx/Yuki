//
//  FloatStrategy.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Strategy that keeps windows in their current positions
class FloatStrategy: TilingStrategy {
    var name: String { "float" }
    var description: String { "Free-floating windows" }
    
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration) {
        // Do nothing - windows remain in their current positions
    }
}
