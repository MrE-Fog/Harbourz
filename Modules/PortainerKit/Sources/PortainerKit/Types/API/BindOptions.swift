//
//  BindOptions.swift
//  PortainerKit
//
//  Created by royal on 17/07/2022.
//

public struct BindOptions: Decodable, Sendable {
	enum CodingKeys: String, CodingKey {
		case propagation = "Propagation"
	}

	public let propagation: Propagation?
}

public extension BindOptions {
	enum Propagation: String, Decodable, Sendable {
		case `private`
		case rprivate
		case shared
		case rshared
		case slave
		case rslave
	}
}
