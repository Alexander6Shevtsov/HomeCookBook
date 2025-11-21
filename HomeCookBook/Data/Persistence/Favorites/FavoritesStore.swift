//
//  FavoritesStore.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 21.11.2025.
//

import Foundation
import CoreData

struct FavoriteItem: Equatable {
	let id: String
	let title: String
	let subtitle: String?
	let thumbnailURL: URL?
	let dateAdded: Date
}

extension Notification.Name {
	static let favoritesDidChange = Notification.Name("favoritesDidChange")
}

protocol FavoritesStore: AnyObject {
	func isFavorite(id: String) async -> Bool
	func add(item: FavoriteItem) async throws
	func remove(id: String) async throws
	func toggle(item: FavoriteItem) async throws -> Bool
	func fetchAll() async throws -> [FavoriteItem]
}

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
			self.postChange()
		}
	}
	
	func remove(id: String) async throws {
		try await backgroundContext.perform {
			if let managedObject = try Self.fetchFavoriteRecipeObject(id: id, in: self.backgroundContext) {
				self.backgroundContext.delete(managedObject)
				try self.backgroundContext.save()
				self.postChange()
			}
		}
	}
	
	func toggle(item: FavoriteItem) async throws -> Bool {
		try await backgroundContext.perform {
			if let managedObject = try Self.fetchFavoriteRecipeObject(id: item.id, in: self.backgroundContext) {
				self.backgroundContext.delete(managedObject)
				try self.backgroundContext.save()
				self.postChange()
				return false
			} else {
				let managedObject = FavoriteRecipeMO(context: self.backgroundContext)
				managedObject.id = item.id
				managedObject.title = item.title
				managedObject.subtitle = item.subtitle
				managedObject.thumbnailURL = item.thumbnailURL?.absoluteString
				managedObject.dateAdded = item.dateAdded
				try self.backgroundContext.save()
				self.postChange()
				return true
			}
		}
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
	
	private static func fetchFavoriteRecipeObject(id: String, in context: NSManagedObjectContext) throws -> FavoriteRecipeMO? {
		let request = NSFetchRequest<FavoriteRecipeMO>(entityName: "FavoriteRecipe")
		request.fetchLimit = 1
		request.predicate = NSPredicate(format: "id == %@", id)
		return try context.fetch(request).first
	}
	
	private nonisolated func postChange() {
		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
		}
	}
}
