//
//  RecipeListContracts.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

protocol RecipeListViewInput: AnyObject {
	func display(items: [RecipeListItemViewModel])
	
	func showLoading(_ isLoading: Bool)
	
	func showError(message: String)
}

protocol RecipeListViewOutput: AnyObject {
	func viewDidLoad()
	
	func didSelectItem(at index: Int)
}

protocol RecipeListInteractorInput: AnyObject {
	func loadInitial()
}

protocol RecipeListInteractorOutput: AnyObject {
	func didLoad(items: [RecipeListItemEntity])
	
	func didFailToLoad(error: Error)
}

protocol RecipeListRouterInput: AnyObject {
	func routeToDetails(mealId: String)
}

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
