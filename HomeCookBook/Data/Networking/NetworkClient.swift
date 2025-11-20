//
//  NetworkClient.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

protocol NetworkClient {
	func get<T: Decodable>(_ url: URL) async throws -> T
}

final class URLSessionNetworkClient: NetworkClient {
	private let session: URLSession
	
	init(session: URLSession = .shared) {
		self.session = session
	}
	
	func get<T: Decodable>(_ url: URL) async throws -> T {
		let (data, response) = try await session.data(from: url)
		guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
			throw URLError(.badServerResponse)
		}
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(T.self, from: data)
	}
}
