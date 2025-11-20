//
//  ImageLoader.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

actor ImageLoader {
	static let shared = ImageLoader()
	
	private let cache = NSCache<NSURL, UIImage>()
	private var inFlight: [URL: Task<UIImage, Error>] = [:]
	
	func image(from url: URL) async throws -> UIImage {
		if let cached = cache.object(forKey: url as NSURL) {
			return cached
		}
		if let task = inFlight[url] {
			return try await task.value
		}
		let task = Task<UIImage, Error> {
			let (data, _) = try await URLSession.shared.data(from: url)
			guard let image = UIImage(data: data) else {
				throw URLError(.cannotDecodeContentData)
			}
			self.cache.setObject(image, forKey: url as NSURL)
			return image
		}
		inFlight[url] = task
		defer { inFlight[url] = nil }
		return try await task.value
	}
	
	func prefetch(url: URL) {
		if cache.object(forKey: url as NSURL) != nil { return }
		if inFlight[url] != nil { return }
		
		let task = Task<UIImage, Error> {
			let (data, _) = try await URLSession.shared.data(from: url)
			guard let image = UIImage(data: data) else {
				throw URLError(.cannotDecodeContentData)
			}
			self.cache.setObject(image, forKey: url as NSURL)
			return image
		}
		inFlight[url] = task
		
		Task {
			_ = try? await task.value
			self.finish(url: url)
		}
	}
	
	func prefetch(urls: [URL]) {
		for url in urls {
			prefetch(url: url)
		}
	}
	
	private func finish(url: URL) {
		inFlight[url] = nil
	}
	
	func clearCache() {
		cache.removeAllObjects()
	}
}
