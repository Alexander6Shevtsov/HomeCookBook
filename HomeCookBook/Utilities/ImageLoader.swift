//
//  ImageLoader.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

actor ImageLoader {
	
	enum ImageLoaderConstants {
		static let memoryLimitMB: Int = 300
		static let fnvPrime: UInt64 = 1099511628211
		static let fnvOffset: UInt64 = 14695981039346656037
		static let fnvHexLength: Int = 16
		static let bitsPerComponent: Int = 8
		static let autoBytesPerRow: Int = 0
		static let jpegQuality: CGFloat = 0.9
	}
	
	static let shared = ImageLoader()
	
	private static let memoryCache: NSCache<NSURL, UIImage> = {
		let cache = NSCache<NSURL, UIImage>()
		cache.totalCostLimit = ImageLoaderConstants.memoryLimitMB * 1024 * 1024
		return cache
	}()
	
	private var inFlight: [URL: Task<UIImage, Error>] = [:]
	private var prefetching: Set<URL> = []
	
	private let fileManager = FileManager.default
	private let diskCacheDirectory: URL
	
	init() {
		let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let dir = caches.appendingPathComponent("ImageCache", isDirectory: true)
		self.diskCacheDirectory = dir
		try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
	}
	
	nonisolated func cachedImage(for url: URL) -> UIImage? {
		Self.memoryCache.object(forKey: url as NSURL)
	}
	
	func image(from url: URL) async throws -> UIImage {
		if let cached = Self.memoryCache.object(forKey: url as NSURL) {
			return cached
		}
		if let diskImage = loadImageFromDisk(for: url) {
			storeInMemoryCache(image: diskImage, for: url)
			return diskImage
		}
		if let task = inFlight[url] {
			prefetching.remove(url)
			let image = try await task.value
			storeInMemoryCache(image: image, for: url)
			return image
		}
		
		let task = Task.detached(priority: .utility) { () -> UIImage in
			return try await Self.fetchAndDecode(url: url)
		}
		inFlight[url] = task
		
		let image = try await task.value
		self.inFlight[url] = nil
		storeInMemoryCache(image: image, for: url)
		Task.detached(priority: .utility) { [weak self] in
			await self?.saveImageToDisk(image: image, for: url)
		}
		return image
	}
	
	func prefetch(url: URL) {
		if Self.memoryCache.object(forKey: url as NSURL) != nil { return }
		if loadImageFromDisk(for: url) != nil { return }
		if inFlight[url] != nil { return }
		
		let task = Task.detached(priority: .utility) { () -> UIImage in
			return try await Self.fetchAndDecode(url: url)
		}
		inFlight[url] = task
		prefetching.insert(url)
		
		Task {
			let image = try? await task.value
			if let image {
				self.storeInMemoryCache(image: image, for: url)
				await self.saveImageToDisk(image: image, for: url)
			}
			self.inFlight[url] = nil
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
	
	func clearCache() {
		Self.memoryCache.removeAllObjects()
		try? fileManager.removeItem(at: diskCacheDirectory)
		try? fileManager.createDirectory(
			at: diskCacheDirectory,
			withIntermediateDirectories: true
		)
	}
	
	private static func fetchAndDecode(url: URL) async throws -> UIImage {
		let (data, _) = try await URLSession.shared.data(from: url)
		guard let image = UIImage(data: data) else {
			throw URLError(.cannotDecodeContentData)
		}
		return Self.decodedImage(image) ?? image
	}
	
	private func storeInMemoryCache(image: UIImage, for url: URL) {
		Self.memoryCache.setObject(image, forKey: url as NSURL, cost: Self.imageCost(image))
	}
	
	private static func imageCost(_ image: UIImage) -> Int {
		guard let cg = image.cgImage else { return 0 }
		return cg.bytesPerRow * cg.height
	}
	
	private func pathForDiskCache(url: URL) -> URL {
		let hash = fnv1a64(url.absoluteString)
		return diskCacheDirectory.appendingPathComponent(hash, isDirectory: false)
	}
	
	private func loadImageFromDisk(for url: URL) -> UIImage? {
		let path = pathForDiskCache(url: url)
		guard fileManager.fileExists(atPath: path.path) else { return nil }
		guard let data = try? Data(contentsOf: path) else { return nil }
		guard let image = UIImage(data: data) else { return nil }
		return Self.decodedImage(image) ?? image
	}
	
	private func saveImageToDisk(image: UIImage, for url: URL) async {
		let path = pathForDiskCache(url: url)
		if fileManager.fileExists(atPath: path.path) { return }
		let data = image.pngData() ?? image.jpegData(compressionQuality: ImageLoaderConstants.jpegQuality)
		guard let data else { return }
		try? data.write(to: path, options: [.atomic])
	}
	
	private func fnv1a64(_ string: String) -> String {
		let prime: UInt64 = ImageLoaderConstants.fnvPrime
		var hash: UInt64 = ImageLoaderConstants.fnvOffset
		for byte in string.utf8 {
			hash ^= UInt64(byte)
			hash &*= prime
		}
		let hex = String(hash, radix: 16)
		let pad = String(repeating: "0", count: max(0, ImageLoaderConstants.fnvHexLength - hex.count))
		return pad + hex
	}
	
	private static func decodedImage(_ image: UIImage) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		let size = CGSize(width: cgImage.width, height: cgImage.height)
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let alphaInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
		let byteOrder = CGBitmapInfo.byteOrder32Little.rawValue
		let bitmapInfo = alphaInfo | byteOrder
		guard let context = CGContext(
			data: nil,
			width: Int(size.width),
			height: Int(size.height),
			bitsPerComponent: ImageLoaderConstants.bitsPerComponent,
			bytesPerRow: ImageLoaderConstants.autoBytesPerRow,
			space: colorSpace,
			bitmapInfo: bitmapInfo
		) else {
			return nil
		}
		context.draw(cgImage, in: CGRect(origin: .zero, size: size))
		guard let newCGImage = context.makeImage() else { return nil }
		return UIImage(cgImage: newCGImage, scale: image.scale, orientation: image.imageOrientation)
	}
}
