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
			let fm = FileManager.default
			let appSupport = try? fm.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			let dir = appSupport ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
			let folder = dir.appendingPathComponent("HomeCookBook", isDirectory: true)
			try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
			return folder.appendingPathComponent("HomeCookBook.sqlite")
		}()
		
		let desc = NSPersistentStoreDescription(url: storeURL)
		desc.type = NSSQLiteStoreType
		desc.shouldAddStoreAsynchronously = false
		container.persistentStoreDescriptions = [desc]
		
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

