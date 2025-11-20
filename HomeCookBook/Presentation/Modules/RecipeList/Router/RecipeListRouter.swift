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
	
	init(viewController: UIViewController, service: MealsService) {
		self.viewController = viewController
		self.service = service
	}
	
	func routeToDetails(mealId: String) {
		let detailsVC = RecipeDetailAssembly.build(mealId: mealId, service: service)
		viewController?.navigationController?.pushViewController(detailsVC, animated: true)
	}
}

