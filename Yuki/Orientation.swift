//
//  Orientation.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

public enum Orientation: Sendable {
    /// Windows are planced along the **horizontal** line
    /// x-axis
    case h
    /// Windows are planced along the **vertical** line
    /// y-axis
    case v
}

public extension Orientation {
    var opposite: Orientation { self == .h ? .v : .h }
}
