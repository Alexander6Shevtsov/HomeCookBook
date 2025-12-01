//
//  FavoriteRecipeMO.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 22.11.2025.
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
