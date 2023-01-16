//
//  AppState+BackgroundTasks.swift
//  Harbour
//
//  Created by royal on 01/10/2022.
//

import Foundation
import BackgroundTasks
import UserNotifications
import WidgetKit
import PortainerKit
import CommonFoundation

// MARK: - AppState+scheduleBackgroundRefresh

extension AppState {

	func scheduleBackgroundRefresh() {
		guard Preferences.shared.enableBackgroundRefresh else {
			logger.info("\(Preferences.Keys.enableBackgroundRefresh, privacy: .public) disabled [\(String._debugInfo(), privacy: .public)]")
			return
		}

		let identifier = HarbourBackgroundTaskIdentifier.backgroundRefresh

		logger.notice("Scheduling background refresh with identifier: \"\(identifier, privacy: .public)\" [\(String._debugInfo(), privacy: .public)]")

		let request = BGAppRefreshTaskRequest(identifier: identifier)
		request.earliestBeginDate = .now

		#if DEBUG
		let debugNotification = UNMutableNotificationContent()
		debugNotification.title = "🚧 Background refresh scheduled!"
		debugNotification.threadIdentifier = "debug"
		let debugNotificationIdentifier = "Debug.BackgroundRefreshScheduled"
		let debugNotificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
		let debugNotificationRequest = UNNotificationRequest(identifier: debugNotificationIdentifier, content: debugNotification, trigger: debugNotificationTrigger)
		UNUserNotificationCenter.current().add(debugNotificationRequest, withCompletionHandler: { _ in })
		#endif

		do {
			try BGTaskScheduler.shared.submit(request)
		} catch {
			// swiftlint:disable:next line_length
			logger.error("Error scheduling background task with identifier: \"\(request.identifier, privacy: .public)\": \(error.localizedDescription, privacy: .public) [\(String._debugInfo(), privacy: .public)]")
		}
	}

}

// MARK: - AppState+handleBackgroundRefresh

extension AppState {

	private enum AppRefreshContainerChange {
		case disappeared(name: String)
		case stateChanged(name: String, from: ContainerState?, to: ContainerState?)
	}

	private static let logPrefix = "BackgroundRefresh"

	@Sendable
	nonisolated func handleBackgroundRefresh() async {
		do {
			logger.notice("[\(Self.logPrefix, privacy: .public)] Handling background refresh... [\(String._debugInfo(), privacy: .public)]")

			#if DEBUG
			Preferences.shared.lastBackgroundRefreshDate = Date().timeIntervalSince1970
			#endif

			#if DEBUG
			Task {
				let debugNotification = UNMutableNotificationContent()
				debugNotification.title = "🚧 Background refresh (oh my god its happening)"
				debugNotification.threadIdentifier = "debug"
				let debugNotificationIdentifier = "Debug.BackgroundRefreshHappening"
				let debugNotificationRequest = UNNotificationRequest(identifier: debugNotificationIdentifier, content: debugNotification, trigger: nil)
				try? await UNUserNotificationCenter.current().add(debugNotificationRequest)
			}
			#endif

			let portainerStore = PortainerStore(urlSessionConfiguration: .intents)

			// Schedule new background refresh
			scheduleBackgroundRefresh()

			// Get pre-refresh containers
			let storedContainers = portainerStore.containers
			let storedContainersStates = storedContainers.reduce(into: [:]) { $0[$1.id] = (name: $1.displayName ?? $1.id, state: $1.state) }

			// Refresh containers, get new state
			let newContainersTask = await PortainerStore.shared.refreshContainers()
			let newContainers = try await newContainersTask.value
			let newContainersStates = newContainers.reduce(into: [:]) { $0[$1.id] = (name: $1.displayName ?? $1.id, state: $1.state) }

			// Find differences
			let differences: [AppRefreshContainerChange] = storedContainersStates
				.compactMap { id, oldState in
					guard let newState = newContainersStates[id] else { return .disappeared(name: oldState.name) }
					if newState.state != oldState.state {
						return .stateChanged(name: oldState.name, from: oldState.state, to: newState.state)
					} else {
						return nil
					}
				}

			#if DEBUG
			Task {
				let debugNotification = UNMutableNotificationContent()
				debugNotification.title = "🚧 Background refresh (oh my god it happened)"
				debugNotification.threadIdentifier = "debug"
				debugNotification.body = differences.description
				let debugNotificationIdentifier = "Debug.BackgroundRefreshHappened"
				let debugNotificationRequest = UNNotificationRequest(identifier: debugNotificationIdentifier, content: debugNotification, trigger: nil)
				try? await UNUserNotificationCenter.current().add(debugNotificationRequest)
			}
			#endif

			// Reload widget timelines
			WidgetCenter.shared.reloadAllTimelines()

			// Handle differences
			if differences.isEmpty {
				logger.debug("[\(Self.logPrefix, privacy: .public)] Differences are empty [\(String._debugInfo(), privacy: .public)]")
				return
			}

			logger.debug("[\(Self.logPrefix, privacy: .public)] Differences count: \(differences.count, privacy: .public) [\(String._debugInfo(), privacy: .public)]")

			if let notificationContent = notificationContent(for: differences) {
				let notificationIdentifier = "\(HarbourNotificationIdentifier.containersChanged).\(differences.description.hashValue)"
				let notificationRequest = UNNotificationRequest(identifier: notificationIdentifier, content: notificationContent, trigger: nil)
				try await UNUserNotificationCenter.current().add(notificationRequest)
			} else {
				logger.warning("[\(Self.logPrefix, privacy: .public)] notificationContent(for:) didn't return anything! [\(String._debugInfo(), privacy: .public)]")
			}

			logger.info("[\(Self.logPrefix, privacy: .public)] Finished handling background refresh :) [\(String._debugInfo(), privacy: .public)]")
		} catch {
			// swiftlint:disable:next line_length
			logger.error("[\(Self.logPrefix, privacy: .public)] Error handling background refresh: \(error.localizedDescription, privacy: .public) [\(String._debugInfo(), privacy: .public)]")
		}
	}

	private nonisolated func notificationContent(for changes: [AppRefreshContainerChange]) -> UNNotificationContent? {
		typealias Localization = Localizable.Notifications.ContainersChanged

		let notificationContent = UNMutableNotificationContent()
		notificationContent.threadIdentifier = HarbourNotificationIdentifier.containersChanged
		notificationContent.interruptionLevel = .active
		notificationContent.relevanceScore = Double(changes.count) / 10
		notificationContent.sound = .default
		/* notificationContent.userInfo = [
			"changes": changes
		] */

		let emoji: String
		let title: String
		let body: String

		switch changes.count {
			case 1:
				// One difference, use singular notification content
				guard let change = changes.first else { return nil }
				title = Localization.Title.containerChanged
				switch change {
					case .disappeared(let name):
						// "😶‍🌫️ Container "<name>" disappeared"
						emoji = "😶‍🌫️"
						body = Localization.Subtitle.containerDisappeared(name)
					case .stateChanged(let name, _, let to):
						// "<emoji> Container "<name>" changed its state to <to>."
						switch to {
							case .dead:
								emoji = "☠️"
							case .created:
								emoji = "🐣" // 👶
							case .exited:
								emoji = "🚪"
							case .paused:
								emoji = "⏸️"
							case .removing:
								emoji = "🗑️"
							case .restarting:
								emoji = "🔄"
							case .running:
								emoji = "🏃"
							case .none:
								emoji = "❔"
						}
						let stateOrUnknown = to?.rawValue ?? Localization.unknownPlaceholder
						body = Localization.Subtitle.containerChangedState(name, stateOrUnknown)
				}
			case 2...3:
				// Multiple differences, readable, use plural notification content
				// "Containers "<container1>", "<container2>" and "<container3>" changed their states"
				let names = changes.map {
					switch $0 {
						case .stateChanged(let name, _, _):
							return "\"\(name)\""
						case .disappeared(let name):
							return "\"\(name)\""
					}
				}
				let namesJoined = names.sorted().formatted(.list(type: .and))
				emoji = "📫" // 🗂️ 👯
				title = Localization.Title.containersChanged
				body = Localization.Subtitle.ContainersChangedStates.readable(namesJoined)
			case 4...:
				// Multiple differences, unreadable, use "multiple changes" notification content
				// "Multiple containers changed their states"
				emoji = "📫" // 🗂️ 👯
				title = Localization.Title.containersChanged
				body = Localization.Subtitle.ContainersChangedStates.unreadable
			default:
				// What
				return nil
		}

		notificationContent.title = "\(emoji) \(title)"
		notificationContent.body = body

		return notificationContent
	}

}