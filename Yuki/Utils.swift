//
//  Utils.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation

// MARK: - UUID Extension

extension UUID: CustomDebugStringConvertible {
    public var debugDescription: String {
        return uuidString.prefix(8).description
    }
}