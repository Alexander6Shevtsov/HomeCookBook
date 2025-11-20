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
	func showRefreshing(_ isRefreshing: Bool)
	func showError(message: String)
}

protocol RecipeListViewOutput: AnyObject {
	func viewDidLoad()
	func didSelectItem(at index: Int)
	func refresh()
	func search(query: String)
	func retry()
}

protocol RecipeListInteractorInput: AnyObject {
	func loadInitial()
	func refresh()
	func search(query: String)
}

protocol RecipeListInteractorOutput: AnyObject {
	func didLoad(items: [RecipeListItemEntity])
	func didFailToLoad(error: Error)
}

protocol RecipeListRouterInput: AnyObject {
	func routeToDetails(mealId: String)
}
