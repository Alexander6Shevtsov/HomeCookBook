//
//  RecipeListRouter.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeListRouter: RecipeListRouterInput {
	
	private weak var viewController: UIViewController?
	
	init(viewController: UIViewController) {
		self.viewController = viewController
	}
	
	func routeToDetails(mealId: String) {
		// TODO: заменить на реальный RecipeDetailAssembly.build(mealId:).
		let alert = UIAlertController(title: "Open Details", message: "Meal ID: \(mealId)", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		viewController?.present(alert, animated: true)
	}
}

