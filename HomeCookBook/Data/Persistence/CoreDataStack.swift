//
//  CoreDataStack.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 21.11.2025.
//

import Foundation
import CoreData

@objc(FavoriteRecipeMO)
final class FavoriteRecipeMO: NSManagedObject {
	@NSManaged var id: String
	@NSManaged var title: String
	@NSManaged var subtitle: String?
	@NSManaged var thumbnailURL: String?
	@NSManaged var dateAdded: Date
}

final class CoreDataStack {
	static let shared = CoreDataStack()
	
	let container: NSPersistentContainer
	
	private init() {
		let model = Self.makeModel()
		container = NSPersistentContainer(name: "HomeCookBookModel", managedObjectModel: model)
		
		let storeURL: URL = {
			let fileManager = FileManager.default
			let appSupport = try? fileManager.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			let directory = appSupport ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
			let folder = directory.appendingPathComponent("HomeCookBook", isDirectory: true)
			try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
			return folder.appendingPathComponent("HomeCookBook.sqlite")
		}()
		
		let description = NSPersistentStoreDescription(url: storeURL)
		description.type = NSSQLiteStoreType
		description.shouldAddStoreAsynchronously = false
		description.shouldMigrateStoreAutomatically = true
		description.shouldInferMappingModelAutomatically = true
		
		container.persistentStoreDescriptions = [description]
		container.loadPersistentStores { _, error in
			if let error {
				assertionFailure("Core Data store loading error: \(error)")
			}
		}
		
		container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
	}
	
	private static func makeModel() -> NSManagedObjectModel {
		let model = NSManagedObjectModel()
		
		let entity = NSEntityDescription()
		entity.name = "FavoriteRecipe"
		entity.managedObjectClassName = String(describing: FavoriteRecipeMO.self)
		
		let id = NSAttributeDescription()
		id.name = "id"
		id.attributeType = .stringAttributeType
		id.isOptional = false
		
		let title = NSAttributeDescription()
		title.name = "title"
		title.attributeType = .stringAttributeType
		title.isOptional = false
		
		let subtitle = NSAttributeDescription()
		subtitle.name = "subtitle"
		subtitle.attributeType = .stringAttributeType
		subtitle.isOptional = true
		
		let thumb = NSAttributeDescription()
		thumb.name = "thumbnailURL"
		thumb.attributeType = .stringAttributeType
		thumb.isOptional = true
		
		let date = NSAttributeDescription()
		date.name = "dateAdded"
		date.attributeType = .dateAttributeType
		date.isOptional = false
		
		entity.properties = [id, title, subtitle, thumb, date]
		entity.uniquenessConstraints = [["id"]]
		
		let idIndexElement = NSFetchIndexElementDescription(property: id, collationType: .binary)
		let idIndex = NSFetchIndexDescription(
			name: "FavoriteRecipe_id_index",
			elements: [idIndexElement]
		)
		entity.indexes = [idIndex]
		
		model.entities = [entity]
		return model
	}
}

