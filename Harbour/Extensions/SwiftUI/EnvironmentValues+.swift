//
//  EnvironmentValues+.swift
//  Harbour
//
//  Created by royal on 23/07/2022.
//

import SwiftUI
import OSLog
import PortainerKit
import IndicatorsKit
import KeychainKit

// MARK: - ErrorHandler

extension EnvironmentValues {
	private struct ErrorHandlerEnvironmentKey: EnvironmentKey {
		static let defaultValue: SceneDelegate.ErrorHandler = { error, _debugInfo in
			assertionFailure("`errorHandler` has been called, but none is attached!")
			os_log(.error, log: .default, "Error: \(error, privacy: .public) [\(_debugInfo, privacy: .public)]")
		}
	}

	/// An action that can handle provided error.
	var errorHandler: SceneDelegate.ErrorHandler {
		get { self[ErrorHandlerEnvironmentKey.self] }
		set { self[ErrorHandlerEnvironmentKey.self] = newValue }
	}
}

// MARK: - ShowIndicator

extension EnvironmentValues {
	private struct ShowIndicatorEnvironmentKey: EnvironmentKey {
		static let defaultValue: SceneDelegate.ShowIndicatorAction = { indicator in
			assertionFailure("`showIndicator` has been called, but none is attached! Indicator: \(indicator)")
		}
	}

	/// An action that shows provided indicator.
	var showIndicator: SceneDelegate.ShowIndicatorAction {
		get { self[ShowIndicatorEnvironmentKey.self] }
		set { self[ShowIndicatorEnvironmentKey.self] = newValue }
	}
}

// MARK: - Logger

extension EnvironmentValues {
	private struct LoggerEnvironmentKey: EnvironmentKey {
		static let defaultValue = Logger(category: Logger.Category.app)
	}

	/// Logging subsystem attached to this view.
	var logger: Logger {
		get { self[LoggerEnvironmentKey.self] }
		set { self[LoggerEnvironmentKey.self] = newValue }
	}
}

// MARK: - PortainerServerURL

extension EnvironmentValues {
	private struct PortainerServerURL: EnvironmentKey {
		static let defaultValue: URL? = nil
	}

	/// Active Portainer server URL.
	var portainerServerURL: URL? {
		get { self[PortainerServerURL.self] }
		set { self[PortainerServerURL.self] = newValue }
	}
}

// MARK: - PortainerSelectedEndpointID

extension EnvironmentValues {
	private struct PortainerSelectedEndpoint: EnvironmentKey {
		static let defaultValue: Endpoint.ID? = nil
	}

	/// Active Portainer endpoint ID.
	var portainerSelectedEndpointID: Endpoint.ID? {
		get { self[PortainerSelectedEndpoint.self] }
		set { self[PortainerSelectedEndpoint.self] = newValue }
	}
}
