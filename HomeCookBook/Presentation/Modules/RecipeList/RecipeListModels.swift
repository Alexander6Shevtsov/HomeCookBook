//
//  RecipeListModels.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

struct RecipeListItemViewModel {
	let id: String
	let title: String
	let subtitle: String?
	let thumbnailURL: URL?
}

struct RecipeListItemEntity {
	let id: String
	let name: String
	let category: String?
	let thumbnailURL: URL?
}

