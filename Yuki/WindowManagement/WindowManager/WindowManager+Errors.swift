//
//  WindowManagerErrors.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa
import CoreFoundation

enum WindowManagerError: Error {
    case notImplemented
    case noMonitorsFound
    case workspaceNotFound
    case windowNotFound
}
