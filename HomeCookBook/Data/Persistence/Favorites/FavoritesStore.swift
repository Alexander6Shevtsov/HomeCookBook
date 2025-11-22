//
//  FavoritesStore.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 21.11.2025.
//

import Foundation
import CoreData

struct FavoriteItem: Equatable, Sendable {
	let id: String
	let title: String
	let subtitle: String?
	let thumbnailURL: URL?
	let dateAdded: Date
}

extension Notification.Name {
	static let favoritesDidChange = Notification.Name("favoritesDidChange")
}

enum FavoritesNotification {
	static let idKey = "id"
	static let isFavoriteKey = "isFavorite"
	static let itemKey = "item"
}

protocol FavoritesStore: AnyObject {
	func isFavorite(id: String) async -> Bool
	func add(item: FavoriteItem) async throws
	func remove(id: String) async throws
	func toggle(item: FavoriteItem) async throws -> Bool
	func fetchAll() async throws -> [FavoriteItem]
}

typealias FavoritesStoreProtocol = FavoritesStore

final actor FavoritesStoreImpl: FavoritesStore {
	private let persistentContainer: NSPersistentContainer
	private let backgroundContext: NSManagedObjectContext
	
	init(container: NSPersistentContainer? = nil) {
		if let container {
			self.persistentContainer = container
		} else {
			self.persistentContainer = MainActor.assumeIsolated {
				CoreDataStack.shared.container
			}
		}
		self.backgroundContext = self.persistentContainer.newBackgroundContext()
		self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
	}
	
	func isFavorite(id: String) async -> Bool {
		await backgroundContext.perform {
			let countRequest = NSFetchRequest<NSNumber>(entityName: "FavoriteRecipe")
			countRequest.resultType = .countResultType
			countRequest.predicate = NSPredicate(format: "id == %@", id)
			let resultCount = (try? self.backgroundContext.count(for: countRequest)) ?? 0
			return resultCount > 0
		}
	}
	
	func add(item: FavoriteItem) async throws {
		try await backgroundContext.perform {
			let managedObject = try Self.fetchFavoriteRecipeObject(id: item.id, in: self.backgroundContext)
			?? FavoriteRecipeMO(context: self.backgroundContext)
			managedObject.id = item.id
			managedObject.title = item.title
			managedObject.subtitle = item.subtitle
			managedObject.thumbnailURL = item.thumbnailURL?.absoluteString
			managedObject.dateAdded = item.dateAdded
			try self.backgroundContext.save()
		}
		await self.postChange(id: item.id, isFavorite: true, item: item)
	}
	
	func remove(id: String) async throws {
		let didDelete: Bool = try await backgroundContext.perform {
			if let managedObject = try Self.fetchFavoriteRecipeObject(id: id, in: self.backgroundContext) {
				self.backgroundContext.delete(managedObject)
				try self.backgroundContext.save()
				return true
			}
			return false
		}
		if didDelete {
			await self.postChange(id: id, isFavorite: false, item: nil)
		}
	}
	
	func toggle(item: FavoriteItem) async throws -> Bool {
		let isNowFavorite: Bool = try await backgroundContext.perform {
			if let managedObject = try Self.fetchFavoriteRecipeObject(id: item.id, in: self.backgroundContext) {
				self.backgroundContext.delete(managedObject)
				try self.backgroundContext.save()
				return false
			} else {
				let managedObject = FavoriteRecipeMO(context: self.backgroundContext)
				managedObject.id = item.id
				managedObject.title = item.title
				managedObject.subtitle = item.subtitle
				managedObject.thumbnailURL = item.thumbnailURL?.absoluteString
				managedObject.dateAdded = item.dateAdded
				try self.backgroundContext.save()
				return true
			}
		}
		await self.postChange(id: item.id, isFavorite: isNowFavorite, item: isNowFavorite ? item : nil)
		return isNowFavorite
	}
	
	func fetchAll() async throws -> [FavoriteItem] {
		try await backgroundContext.perform {
			let request = NSFetchRequest<FavoriteRecipeMO>(entityName: "FavoriteRecipe")
			request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
			let managedObjects = try self.backgroundContext.fetch(request)
			return managedObjects.map { managedObject in
				FavoriteItem(
					id: managedObject.id,
					title: managedObject.title,
					subtitle: managedObject.subtitle,
					thumbnailURL: managedObject.thumbnailURL.flatMap(URL.init(string:)),
					dateAdded: managedObject.dateAdded
				)
			}
		}
	}
	
	private static func fetchFavoriteRecipeObject(
		id: String,
		in context: NSManagedObjectContext
	) throws -> FavoriteRecipeMO? {
		let request = NSFetchRequest<FavoriteRecipeMO>(entityName: "FavoriteRecipe")
		request.fetchLimit = 1
		request.predicate = NSPredicate(format: "id == %@", id)
		return try context.fetch(request).first
	}
	
	@MainActor
	private func postChange(id: String, isFavorite: Bool, item: FavoriteItem?) {
		let userInfo: [AnyHashable: Any] = {
			var dict: [AnyHashable: Any] = [
				FavoritesNotification.idKey: id,
				FavoritesNotification.isFavoriteKey: isFavorite
			]
			if let item {
				dict[FavoritesNotification.itemKey] = item
			}
			return dict
		}()
		NotificationCenter.default.post(name: .favoritesDidChange, object: nil, userInfo: userInfo)
	}
}

