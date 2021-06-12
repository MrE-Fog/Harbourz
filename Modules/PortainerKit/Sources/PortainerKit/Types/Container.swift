//
//  Container.swift
//  PortainerKit
//
//  Created by royal on 11/06/2021.
//

import Foundation

@available(iOS 15, macOS 12, *)
public extension PortainerKit {
	class Container: Identifiable, Codable, Equatable {
		enum CodingKeys: String, CodingKey {
			case id = "Id"
			case names = "Names"
			case image = "Image"
			case imageID = "ImageID"
			case command = "Command"
			case created = "Created"
			case ports = "Ports"
			case sizeRW = "SizeRw"
			case sizeRootFS = "SizeRootFs"
			case labels = "Labels"
			case state = "State"
			case status = "Status"
			case hostConfig = "HostConfig"
			case networkSettings = "NetworkSettings"
			case mounts = "Mounts"
		}
		
		public let id: String
		public let names: [String]?
		public let image: String
		public let imageID: String
		public let command: String?
		public let created: Date?
		public let ports: [Port]?
		public let sizeRW: Int64?
		public let sizeRootFS: Int64?
		public let labels: [String: String]?
		public var state: ContainerStatus?
		public var status: String?
		public let hostConfig: HostConfig?
		public let networkSettings: NetworkSettings?
		public let mounts: [Mount]?
		
		public static func == (lhs: PortainerKit.Container, rhs: PortainerKit.Container) -> Bool {
			lhs.id == rhs.id &&
			lhs.state == rhs.state &&
			lhs.status == rhs.status &&
			lhs.names == rhs.names &&
			lhs.labels == rhs.labels
		}
	}
}