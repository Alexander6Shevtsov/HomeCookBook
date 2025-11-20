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
		let details = RecipeDetailAssembly.build(mealId: mealId)
		viewController?.navigationController?.pushViewController(details, animated: true)
	}
}
