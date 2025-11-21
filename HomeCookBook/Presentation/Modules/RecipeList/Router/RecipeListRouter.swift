//
//  RecipeListRouter.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeListRouter: RecipeListRouterInput {
	private weak var viewController: UIViewController?
	private let service: MealsService
	private let favoritesStore: FavoritesStore
	
	init(viewController: UIViewController, service: MealsService, favoritesStore: FavoritesStore) {
		self.viewController = viewController
		self.service = service
		self.favoritesStore = favoritesStore
	}
	
	func routeToDetails(mealId: String, initialTitle: String?) {
		let detailsVC = RecipeDetailAssembly.build(
			mealId: mealId,
			initialTitle: initialTitle,
			service: service,
			favoritesStore: favoritesStore
		)
		viewController?.navigationController?.pushViewController(detailsVC, animated: true)
	}
	
	func routeToFavorites() {
		let favoritesVC = FavoritesListViewController(favoritesStore: favoritesStore)
		favoritesVC.onSelect = { [weak self] mealId, title in
			self?.routeToDetails(mealId: mealId, initialTitle: title)
		}
		viewController?.navigationController?.pushViewController(favoritesVC, animated: true)
	}
}

