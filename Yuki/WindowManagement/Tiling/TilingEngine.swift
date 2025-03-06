//
//  TilingEngine.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Cocoa
import Foundation

/// Central service for tiling operations
class TilingEngine {
    // MARK: - Properties

    /// Reference to the workspace this engine manages
    weak var workspace: WorkspaceNode?

    /// Current tiling strategy
    private var strategy: TilingStrategy

    /// Configuration for tiling
    var config: TilingConfiguration

    // MARK: - Initialization

    /// Initialize with a workspace and optional strategy
    init(
        workspace: WorkspaceNode? = nil,
        initialStrategy: TilingStrategy = BSPStrategy()
    ) {
        self.workspace = workspace
        self.strategy = initialStrategy
        self.config = TilingConfiguration()
    }

    // MARK: - Tiling Operations

    /// Apply current tiling strategy to windows
    func applyTiling() {
        guard let workspace = workspace else { return }
        let monitor = workspace.monitor

        let windows = workspace.getAllWindowNodes()
        let availableRect = monitor.visibleFrame

        strategy.applyLayout(to: windows, in: availableRect, with: config)
    }

    /// Change the tiling strategy
    func setStrategy(_ strategy: TilingStrategy) {
        self.strategy = strategy
        applyTiling()
    }

    /// Change the tiling mode by name
    func setTilingMode(_ modeName: String) {
        let strategy: TilingStrategy

        switch modeName.lowercased() {
        case "float":
            strategy = FloatStrategy()
        case "hstack":
            strategy = HStackStrategy()
        case "vstack":
            strategy = VStackStrategy()
        case "zstack":
            strategy = ZStackStrategy()
        case "bsp":
            strategy = BSPStrategy()
        default:
                strategy = BSPStrategy()
        }

        setStrategy(strategy)
    }

    /// Cycle to the next tiling mode
    @discardableResult
    func cycleToNextMode() -> TilingStrategy {
        let currentName = strategy.name

        let nextStrategy: TilingStrategy
        switch currentName {
        case "float":
            nextStrategy = HStackStrategy()
        case "hstack":
            nextStrategy = VStackStrategy()
        case "vstack":
            nextStrategy = ZStackStrategy()
        case "zstack":
            nextStrategy = BSPStrategy()
        case "bsp":
            nextStrategy = FloatStrategy()
        default:
            nextStrategy = BSPStrategy()
        }

        setStrategy(nextStrategy)
        return nextStrategy
    }

    /// Get current strategy name
    var currentModeName: String {
        return strategy.name
    }

    /// Get current strategy description
    var currentModeDescription: String {
        return strategy.description
    }
}
