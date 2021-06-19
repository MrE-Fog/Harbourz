//
//  AppState.swift
//  Harbour
//
//  Created by royal on 11/06/2021.
//

import Foundation
import os.log
import AppNotifications

class AppState: ObservableObject {
	public static let shared: AppState = AppState()

	@Published public var isSettingsViewPresented: Bool = false
	@Published public var isContainerConsoleViewPresented: Bool = false
	@Published public var isSetupViewPresented: Bool = false
	
	public let errorNotifications: AppNotifications = AppNotifications()
	public let persistenceNotifications: AppNotifications = AppNotifications()

	private let logger: Logger = Logger(subsystem: "\(Bundle.main.bundleIdentifier ?? "Harbour").AppState", category: "AppState")

	private init() {
		if !Preferences.shared.launchedBefore { isSetupViewPresented = true }
	}

	public func handle(_ error: Error, displayNotification: Bool = true, _fileID: StaticString = #fileID, _line: Int = #line) {
		self.logger.error("\(String(describing: error)) [\(_fileID):\(_line)]")
		
		if displayNotification {
			let notification: AppNotifications.Notification = .init(id: UUID().uuidString, dismissType: .timeout(5), icon: "xmark", title: "Error!", description: error.localizedDescription, backgroundStyle: .colorAndMaterial(color: .red.opacity(0.5), material: .regularMaterial))
			errorNotifications.add(notification)
		}
	}
}
