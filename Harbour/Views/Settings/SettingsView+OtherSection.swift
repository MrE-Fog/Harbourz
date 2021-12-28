//
//  SettingsView+OtherSection.swift
//  Harbour
//
//  Created by royal on 18/08/2021.
//

import SwiftUI

extension SettingsView {
	struct OtherSection: View {
		var madeWithLove: some View {
			Link(destination: URL(string: "https://github.com/rrroyal/Harbour")!) {
				VStack(spacing: 5) {
					Text(Localization.SETTINGS_FOOTER.localized)
					Text("Harbour v\(Bundle.main.buildVersion) (#\(Bundle.main.buildNumber))")
				}
				.font(.subheadline.weight(.semibold))
				.opacity(Constants.secondaryOpacity)
			}
			.tint(.secondary)
			.frame(maxWidth: .infinity, alignment: .center)
			.padding(.top)
		}
		
		var body: some View {
			Section(header: Text("Other"), footer: madeWithLove) {
				NavigationLink("Libraries") {
					LibrariesView()
				}
				
				#if DEBUG
				NavigationLink("🤫") {
					DebugView()
				}
				#endif
				
				Link(destination: URL(string: "https://harbour.shameful.xyz/docs")!) {
					HStack {
						Text("Docs")
						Spacer()
						Image(systemName: "globe")
					}
				}
				.accentColor(.primary)
			}
		}
	}
}

extension SettingsView.OtherSection {
	struct LibrariesView: View {
		typealias Library = (url: URL, label: String)
		
		let libraries: [Library] = [
			(URL(string: "https://github.com/kishikawakatsumi/KeychainAccess")!, "kishikawakatsumi/KeychainAccess")
		]
		
		var body: some View {
			List(libraries, id: \.url) { library in
				Link(destination: library.url) {
					HStack {
						Text(library.label)
						Spacer()
						Image(systemName: "globe")
					}
				}
				.accentColor(.primary)
			}
			.navigationTitle("Libraries")
		}
	}
}
