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
	private var prefetching: Set<URL> = []
	
	private static func fetchImage(url: URL) async throws -> UIImage {
		let (data, _) = try await URLSession.shared.data(from: url)
		guard let image = UIImage(data: data) else {
			throw URLError(.cannotDecodeContentData)
		}
		return image
	}
	
	func image(from url: URL) async throws -> UIImage {
		if let cached = cache.object(forKey: url as NSURL) {
			return cached
		}
		if let task = inFlight[url] {
			prefetching.remove(url)
			let image = try await task.value
			cache.setObject(image, forKey: url as NSURL)
			return image
		}
		
		let task = Task.detached(priority: nil) { () -> UIImage in
			try await Self.fetchImage(url: url)
		}
		inFlight[url] = task
		defer { inFlight[url] = nil }
		
		let image = try await task.value
		cache.setObject(image, forKey: url as NSURL)
		return image
	}
	
	func prefetch(url: URL) {
		if cache.object(forKey: url as NSURL) != nil { return }
		if inFlight[url] != nil { return }
		
		let task = Task.detached(priority: .utility) { () -> UIImage in
			try await Self.fetchImage(url: url)
		}
		inFlight[url] = task
		prefetching.insert(url)
		
		Task {
			let image = try? await task.value
			if let image {
				self.cache.setObject(image, forKey: url as NSURL)
			}
			self.finish(url: url)
			self.prefetching.remove(url)
		}
	}
	
	func prefetch(urls: [URL]) {
		for url in urls {
			prefetch(url: url)
		}
	}
	
	func cancelPrefetch(url: URL) {
		guard prefetching.contains(url) else { return }
		if let task = inFlight[url] {
			task.cancel()
		}
		inFlight[url] = nil
		prefetching.remove(url)
	}
	
	func cancelAllPrefetches() {
		for url in prefetching {
			if let task = inFlight[url] {
				task.cancel()
			}
			inFlight[url] = nil
		}
		prefetching.removeAll()
	}
	
	private func finish(url: URL) {
		inFlight[url] = nil
	}
	
	func clearCache() {
		cache.removeAllObjects()
	}
}
