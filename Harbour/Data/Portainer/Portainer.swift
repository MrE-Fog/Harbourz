//
//  Portainer.swift
//  Harbour
//
//  Created by unitears on 11/06/2021.
//

import Combine
import KeychainAccess
import os.log
import PortainerKit
import SwiftUI

final class Portainer: ObservableObject {
	// MARK: - Public properties

	public static let shared: Portainer = Portainer()
	
	// MARK: Miscellaneous
	
	@Published public var isLoggedIn: Bool = false
	
	// MARK: Endpoint
	
	@Published public var selectedEndpoint: PortainerKit.Endpoint? = nil {
		didSet {
			if let endpointID = selectedEndpoint?.id {
				Task {
					do {
						try await getContainers(endpointID: endpointID)
					} catch {
						AppState.shared.handle(error)
					}
				}
			} else {
				containers = []
			}
		}
	}

	@Published public private(set) var endpoints: [PortainerKit.Endpoint] = [] {
		didSet {
			if endpoints.count == 1 {
				selectedEndpoint = endpoints.first
			} else if endpoints.isEmpty {
				selectedEndpoint = nil
			}
		}
	}
	
	// MARK: Containers
	
	public let refreshCurrentContainerPassthroughSubject: PassthroughSubject<Void, Never> = .init()
	@Published public var attachedContainer: AttachedContainer? = nil
	@Published public private(set) var containers: [PortainerKit.Container] = []
	
	// MARK: - Private properties
	
	private let logger: Logger = Logger(subsystem: "\(Bundle.main.bundleIdentifier ?? "Harbour").Portainer", category: "Portainer")
	private let keychain: Keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "Harbour").label("Harbour").synchronizable(true).accessibility(.afterFirstUnlock)
	private let ud: UserDefaults = Preferences.shared.ud
	private var api: PortainerKit?
	
	// MARK: - init
	
	private init() {
		// Check if endpointURL is saved
		if let urlString = Preferences.shared.endpointURL, let url = URL(string: urlString) {
			// It is, try to log in
			logger.debug("Has saved URL: \(url, privacy: .sensitive)")
			
			Task {
				// Check if token is saved
				if let token = keychain[KeychainKeys.token] {
					// Yeah - use it and fetch endpoints
					logger.debug("Also has token, cool! Using it 😊")
					self.api = PortainerKit(url: url, token: token)
					
					do {
						try await self.getEndpoints()
					} catch {
						// Something went wrong! Check if token was invalid and has saved credentials
						if error as? PortainerKit.APIError == PortainerKit.APIError.invalidJWTToken,
						   let username = keychain[KeychainKeys.username], let password = keychain[KeychainKeys.password] {
							// Yup - try to use them to refresh the token
							logger.debug("Saved token is invalid, but has credentials!")
							
							do {
								try await login(url: url, username: username, password: password, savePassword: true)
								try await self.getEndpoints()
								// Success!
							} catch {
								// Something went wrong - log out 😞
								logOut()
								AppState.shared.handle(error)
							}
						} else {
							// Error was regarding something else OR there's no saved credentials 😕
							AppState.shared.handle(error)
							logOut()
						}
					}
				} else if let username = keychain[KeychainKeys.username], let password = keychain[KeychainKeys.password] {
					// No token BUT has credentials! Try to use them...
					logger.debug("No saved token, but has credentials!")
					
					do {
						try await login(url: url, username: username, password: password, savePassword: true)
						try await self.getEndpoints()
						// Got it!
					} catch {
						// Something went wrong 😑
						logOut()
						AppState.shared.handle(error)
					}
				}
			}
		}
	}
	
	// MARK: - Public functions
	
	/// Logs in to Portainer.
	/// - Parameters:
	///   - url: Endpoint URL
	///   - username: Username
	///   - password: Password
	///   - savePassword: Should password be saved?
	/// - Returns: Result containing JWT token or error.
	public func login(url: URL, username: String, password: String, savePassword: Bool) async throws {
		logger.debug("Logging in! URL: \(url.absoluteString, privacy: .sensitive)")
		let api = PortainerKit(url: url)
		self.api = api
		
		let activeActionID = generateActionID(url, username, password)
		AppState.shared.activeNetworkActivities.insert(activeActionID)
		defer { AppState.shared.activeNetworkActivities.remove(activeActionID) }
		
		let token = try await api.login(username: username, password: password)
		
		logger.debug("Successfully logged in!")
		
		DispatchQueue.main.async { [weak self] in
			self?.isLoggedIn = true
			Preferences.shared.endpointURL = url.absoluteString
		}
		keychain[KeychainKeys.token] = token
		
		if savePassword {
			keychain[KeychainKeys.username] = username
			keychain[KeychainKeys.password] = password
		}
	}
	
	/// Logs out, removing all local authentication.
	public func logOut() {
		logger.info("Logging out")
		
		try? keychain.removeAll()
		
		isLoggedIn = false
		selectedEndpoint = nil
		endpoints = []
		containers = []
		attachedContainer = nil
		
		Preferences.shared.endpointURL = nil
	}
	
	/// Fetches available endpoints.
	/// - Returns: `[PortainerKit.Endpoint]`
	@discardableResult
	public func getEndpoints() async throws -> [PortainerKit.Endpoint] {
		logger.debug("Getting endpoints...")
		
		guard let api = api else { throw PortainerError.noAPI }
		
		let activeActionID = generateActionID()
		AppState.shared.activeNetworkActivities.insert(activeActionID)
		defer { AppState.shared.activeNetworkActivities.remove(activeActionID) }
		
		do {
			let endpoints = try await api.getEndpoints()
			
			logger.debug("Got \(endpoints.count) endpoint(s).")
			DispatchQueue.main.async { [weak self] in
				self?.endpoints = endpoints
				self?.isLoggedIn = true
			}
			
			return endpoints
		} catch {
			DispatchQueue.main.async { [weak self] in
				self?.endpoints = []
				
				if let error = error as? PortainerKit.APIError, error == .invalidJWTToken {
					self?.isLoggedIn = false
				}
			}
			
			throw error
		}
	}
	
	/// Fetches available containers for selected endpoint ID.
	/// - Parameter endpointID: Endpoint ID
	/// - Returns: `[PortainerKit.Container]`
	@discardableResult
	public func getContainers(endpointID: Int) async throws -> [PortainerKit.Container] {
		logger.debug("Getting containers for endpointID: \(endpointID)...")
		
		guard let api = api else { throw PortainerError.noAPI }

		let activeActionID = generateActionID(endpointID)
		AppState.shared.activeNetworkActivities.insert(activeActionID)
		defer { AppState.shared.activeNetworkActivities.remove(activeActionID) }

		do {
			let containers = try await api.getContainers(for: endpointID)
			
			logger.debug("Got \(containers.count) container(s) for endpointID: \(endpointID).")
			DispatchQueue.main.async { [weak self] in
				self?.containers = containers
			}
			
			return containers
		} catch {
			DispatchQueue.main.async { [weak self] in
				self?.containers = []
				
				if let error = error as? PortainerKit.APIError, error == .invalidJWTToken {
					self?.isLoggedIn = false
				}
			}
			
			throw error
		}
	}
	
	/// Fetches container details.
	/// - Parameter container: Container to be inspected
	/// - Returns: `PortainerKit.ContainerDetails`
	public func inspectContainer(_ container: PortainerKit.Container) async throws -> PortainerKit.ContainerDetails {
		logger.debug("Inspecting container with ID: \(container.id), endpointID: \(self.selectedEndpoint?.id ?? -1)...")
		
		guard let api = api else { throw PortainerError.noAPI }
		guard let endpointID = selectedEndpoint?.id else { throw PortainerError.noEndpoint }

		let activeActionID = generateActionID(container.id)
		AppState.shared.activeNetworkActivities.insert(activeActionID)
		defer { AppState.shared.activeNetworkActivities.remove(activeActionID) }
		
		do {
			let containerDetails = try await api.inspectContainer(container.id, endpointID: endpointID)
			logger.debug("Got details for containerID: \(container.id), endpointID: \(endpointID).")
			return containerDetails
		} catch {
			if let error = error as? PortainerKit.APIError, error == .invalidJWTToken {
				DispatchQueue.main.async { [weak self] in
					self?.isLoggedIn = false
				}
			}
			
			throw error
		}
	}
	
	/// Executes an action on selected container.
	/// - Parameters:
	///   - action: Action to be executed
	///   - container: Container, where the action will be executed
	public func execute(_ action: PortainerKit.ExecuteAction, on container: PortainerKit.Container) async throws {
		logger.debug("Executing action \(action.rawValue) for containerID: \(container.id), endpointID: \(self.selectedEndpoint?.id ?? -1)...")
		
		guard let api = api else { throw PortainerError.noAPI }
		guard let endpointID = selectedEndpoint?.id else { throw PortainerError.noEndpoint }
		
		let activeActionID = generateActionID(action, container.id)
		AppState.shared.activeNetworkActivities.insert(activeActionID)
		defer { AppState.shared.activeNetworkActivities.remove(activeActionID) }
		
		do {
			try await api.execute(action, containerID: container.id, endpointID: endpointID)
			logger.debug("Executed action \(action.rawValue) for containerID: \(container.id), endpointID: \(endpointID).")
		} catch {
			if let error = error as? PortainerKit.APIError, error == .invalidJWTToken {
				DispatchQueue.main.async { [weak self] in
					self?.isLoggedIn = false
				}
			}
			
			throw error
		}
	}
	
	/// Fetches logs from selected container.
	/// - Parameters:
	///   - container: Get logs from this container
	///   - since: Logs since this time
	///   - tail: Number of lines
	///   - displayTimestamps: Display timestamps?
	/// - Returns: `String` logs
	public func getLogs(from container: PortainerKit.Container, since: TimeInterval = 0, tail: Int = 100, displayTimestamps: Bool = false) async throws -> String {
		logger.debug("Getting logs from containerID: \(container.id), endpointID: \(self.selectedEndpoint?.id ?? -1)...")
		
		guard let api = api else { throw PortainerError.noAPI }
		guard let endpointID = selectedEndpoint?.id else { throw PortainerError.noEndpoint }
		
		let activeActionID = generateActionID(container.id)
		AppState.shared.activeNetworkActivities.insert(activeActionID)
		defer { AppState.shared.activeNetworkActivities.remove(activeActionID) }

		do {
			let logs = try await api.getLogs(containerID: container.id, endpointID: endpointID, since: since, tail: tail, displayTimestamps: displayTimestamps)
			logger.debug("Got logs from containerID: \(container.id), endpointID: \(self.selectedEndpoint?.id ?? -1)!")
			return logs
		} catch {
			if let error = error as? PortainerKit.APIError, error == .invalidJWTToken {
				DispatchQueue.main.async { [weak self] in
					self?.isLoggedIn = false
				}
			}
			
			throw error
		}
	}
	
	/// Attaches to container through a WebSocket connection.
	/// - Parameter container: Container to attach to
	/// - Returns: Result containing `AttachedContainer` or error.
	@discardableResult
	public func attach(to container: PortainerKit.Container) throws -> AttachedContainer {
		if let attachedContainer = attachedContainer, attachedContainer.container.id == container.id {
			return attachedContainer
		}
		
		logger.debug("Attaching to containerID: \(container.id), endpointID: \(self.selectedEndpoint?.id ?? -1)...")
		
		guard let api = api else { throw PortainerError.noAPI }
		guard let endpointID = selectedEndpoint?.id else { throw PortainerError.noEndpoint }
		
		let activeActionID = generateActionID(container.id)
		AppState.shared.activeNetworkActivities.insert(activeActionID)
		defer { AppState.shared.activeNetworkActivities.remove(activeActionID) }
		
		do {
			let messagePassthroughSubject = try api.attach(to: container.id, endpointID: endpointID)
			logger.debug("Attached to containerID: \(container.id), endpointID: \(self.selectedEndpoint?.id ?? -1)!")
			
			let attachedContainer = AttachedContainer(container: container, messagePassthroughSubject: messagePassthroughSubject)
			self.attachedContainer = attachedContainer
			
			return attachedContainer
		} catch {
			if let error = error as? PortainerKit.APIError, error == .invalidJWTToken {
				DispatchQueue.main.async { [weak self] in
					self?.isLoggedIn = false
				}
			}
			
			throw error
		}
	}
	
	// MARK: - Private functions
	
	private func generateActionID(_ args: Any..., _function: StaticString = #function) -> String {
		"Portainer.\(_function)(\(String(describing: args)))"
	}
}

private extension Portainer {
	enum KeychainKeys {
		static let token: String = "token"
		static let username: String = "username"
		static let password: String = "password"
	}
}
