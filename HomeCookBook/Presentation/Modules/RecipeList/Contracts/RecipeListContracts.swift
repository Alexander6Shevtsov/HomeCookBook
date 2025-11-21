//
//  RecipeListContracts.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

protocol RecipeListViewInput: AnyObject {
	func display(items: [RecipeListItemViewModel])
	func showError(message: String)
}

protocol RecipeListViewOutput: AnyObject {
	func viewDidLoad()
	func didSelectItem(at index: Int)
	func refresh()
	func search(query: String)
	func retry()
	func loadMore()
	func showFavorites()
}

protocol RecipeListInteractorInput: AnyObject {
	func loadInitial()
	func refresh()
	func search(query: String)
	func loadMoreNextLetter()
}

protocol RecipeListInteractorOutput: AnyObject {
	func didLoad(items: [RecipeListItemEntity])
	func didLoadMore(items: [RecipeListItemEntity])
	func didFailToLoad(error: Error)
}

protocol RecipeListRouterInput: AnyObject {
	func routeToDetails(mealId: String, initialTitle: String?)
	func routeToFavorites()
}
