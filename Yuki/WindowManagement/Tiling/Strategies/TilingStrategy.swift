//
//  TilingStrategy.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Protocol defining a tiling strategy
protocol TilingStrategy {
    /// Apply layout to the given windows within the available space
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration)
    
    /// Name of the strategy
    var name: String { get }
    
    /// Description of the strategy
    var description: String { get }
}
