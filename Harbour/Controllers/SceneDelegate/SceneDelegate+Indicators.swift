//
//  SceneDelegate+Indicators.swift
//  Harbour
//
//  Created by royal on 29/01/2023.
//

import Foundation
import PortainerKit
import IndicatorsKit

// MARK: - SceneDelegate+Indicators

extension SceneDelegate {
	typealias ShowIndicatorAction = (PresentedIndicator) -> Void

	func showIndicator(_ presentedIndicator: PresentedIndicator) {
		let indicator: Indicator

		switch presentedIndicator {
		case .error(let error):
			indicator = Indicator(error: error)
		case .copied:
			let style: Indicator.Style = .default
			indicator = Indicator(id: presentedIndicator.id,
								  icon: SFSymbol.copy,
								  headline: Localizable.Indicators.copied,
								  style: style)
		case .containerActionExecuted(_, let containerName, let action):
			let style: Indicator.Style = .init(subheadlineColor: action.color,
											   subheadlineStyle: .primary,
											   iconColor: action.color,
											   iconStyle: .primary,
											   iconVariants: .fill)
			indicator = .init(id: presentedIndicator.id,
							  icon: action.icon,
							  headline: containerName ?? Localizable.PortainerKit.Generic.container,
							  subheadline: action.label,
							  style: style)
		}

		Task { @MainActor in
			indicators.display(indicator)
		}
	}
}

// MARK: - SceneDelegate+PresentedIndicator

extension SceneDelegate {
	enum PresentedIndicator: Identifiable {
		case containerActionExecuted(Container.ID, String?, ExecuteAction)
		case copied
		case error(Error)

		var id: String {
			switch self {
			case .containerActionExecuted(let containerID, _, let action):
				return "ContainerActionExecutedIndicator.\(containerID).\(action.rawValue)"
			case .copied:
				return "CopiedIndicator.\(UUID().uuidString)"
			case .error(let error):
				return "ErrorIndicator.\(String(describing: error).hashValue)"
			}
		}
	}
}
