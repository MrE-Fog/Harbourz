//
//  SettingsView+PortainerSection.swift
//  Harbour
//
//  Created by royal on 18/08/2021.
//

import SwiftUI
import UserNotifications

extension SettingsView {
	struct PortainerSection: View {
		@EnvironmentObject var appState: AppState
		@EnvironmentObject var sceneState: SceneState
		@EnvironmentObject var portainer: Portainer
		@EnvironmentObject var preferences: Preferences
		
		@State private var isLoginSheetPresented: Bool = false
		@State private var isLogoutWarningPresented: Bool = false
		
		var autoRefreshIntervalDescription: String {
			guard preferences.autoRefreshInterval > 0 else {
				return "Off"
			}
			
			let formatter = DateComponentsFormatter()
			formatter.allowedUnits = [.second]
			formatter.unitsStyle = .full
			
			return formatter.string(from: preferences.autoRefreshInterval) ?? "\(preferences.autoRefreshInterval) second(s)"
		}
		
		var body: some View {
			Group {
				Section("Portainer") {
					Menu(content: {
						ForEach(portainer.servers, id: \.absoluteString) { server in
							Menu(server.absoluteString) {
								if portainer.serverURL == server {
									Label("In use", systemImage: "checkmark")
										.symbolVariant(.circle.fill)
								} else {
									Button(action: {
										UIDevice.generateHaptic(.selectionChanged)
										do {
											try portainer.setup(with: server)
										} catch {
											UIDevice.generateHaptic(.error)
											sceneState.handle(error)
										}
									}) {
										Label("Use", systemImage: "checkmark")
											.symbolVariant(.circle)
									}
								}
								
								Divider()
								
								Button(role: .destructive, action: {
									UIDevice.generateHaptic(.heavy)
									do {
										try portainer.removeServer(url: server)
									} catch {
										UIDevice.generateHaptic(.error)
										sceneState.handle(error)
									}
								}) {
									Label("Delete", systemImage: "trash")
								}
							}
						}
						
						Divider()
						
						Button(action: {
							UIDevice.generateHaptic(.soft)
							isLoginSheetPresented = true
						}) {
							Label("Add", systemImage: "plus")
						}
					}) {
						Text(preferences.selectedServer?.absoluteString ?? "No server selected")
							.frame(maxWidth: .infinity, alignment: .leading)
							.transition(.identity)
							.id("SelectedServerLabel:\(preferences.selectedServer?.absoluteString ?? "")")
						
						Image(systemName: "chevron.down")
					}
					.id("ServerSelectionMenu:\(portainer.servers.hashValue)")
				}
				.sheet(isPresented: $isLoginSheetPresented) {
					LoginView()
				}
				
				Section("Data") {
					/// Persist attached container
					ToggleOption(label: Localization.SETTINGS_PERSIST_ATTACHED_CONTAINER_TITLE.localized, description: Localization.SETTINGS_PERSIST_ATTACHED_CONTAINER_DESCRIPTION.localized, isOn: $preferences.persistAttachedContainer)
					
					/// Refresh containers in background
					ToggleOption(label: Localization.SETTINGS_BACKGROUND_REFRESH_TITLE.localized, description: Localization.SETTINGS_BACKGROUND_REFRESH_DESCRIPTION.localized, isOn: preferences.$enableBackgroundRefresh)
						.onChange(of: preferences.enableBackgroundRefresh, perform: setupBackgroundRefresh)
					
					/// Auto-refresh interval
					SliderOption(label: Localization.SETTINGS_AUTO_REFRESH_TITLE.localized, description: autoRefreshIntervalDescription, value: $preferences.autoRefreshInterval, range: 0...60, step: 1, onEditingChanged: setupAutoRefreshTimer)
				}
			}
		}
		
		private func setupBackgroundRefresh(isOn: Bool) {
			guard isOn else {
				AppState.shared.cancelBackgroundRefreshTask()
				return
			}
			
			Task {
				do {
					try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
					AppState.shared.scheduleBackgroundRefreshTask()
				} catch {
					AppState.shared.cancelBackgroundRefreshTask()
					preferences.enableBackgroundRefresh = false
					sceneState.handle(error)
				}
			}
		}
		
		private func setupAutoRefreshTimer(isEditing: Bool) {
			guard !isEditing else { return }
			AppState.shared.setupAutoRefreshTimer(interval: preferences.autoRefreshInterval)
		}
	}
}
