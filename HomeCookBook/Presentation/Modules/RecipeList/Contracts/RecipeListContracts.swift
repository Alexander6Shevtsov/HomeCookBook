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
	func showCategoryMenu(categories: [String], selected: String?)
}

protocol RecipeListViewOutput: AnyObject {
	func viewDidLoad()
	func didSelectItem(at index: Int, previewImage: UIImage?)
	func refresh()
	func search(query: String)
	func retry()
	func loadMore()
	func showFavorites()
	func requestCategories()
	func selectCategory(_ name: String?)
}

protocol RecipeListInteractorInput: AnyObject {
	func loadInitial()
	func refresh()
	func search(query: String)
	func loadMoreNextLetter()
	func fetchCategories()
	func searchCategory(_ name: String)
}

protocol RecipeListInteractorOutput: AnyObject {
	func didLoad(items: [RecipeListItemEntity])
	func didLoadMore(items: [RecipeListItemEntity])
	func didFailToLoad(error: Error)
	func didLoadCategories(_ categories: [String])
}

protocol RecipeListRouterInput: AnyObject {
	func routeToDetails(
		mealId: String,
		initialTitle: String?,
		initialImageURL: URL?,
		initialImage: UIImage?
	)
	func routeToFavorites()
}

