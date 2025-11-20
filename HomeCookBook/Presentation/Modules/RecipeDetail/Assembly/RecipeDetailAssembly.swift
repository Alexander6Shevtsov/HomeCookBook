//
//  RecipeDetailAssembly.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

enum RecipeDetailAssembly {
	static func build(mealId: String, service: MealsService) -> UIViewController {
		let view = RecipeDetailViewController()
		let router = RecipeDetailRouter(viewController: view)
		let interactor = RecipeDetailInteractor(mealId: mealId, service: service, output: nil)
		let presenter = RecipeDetailPresenter(
			view: view,
			interactor: interactor,
			router: router,
			mealId: mealId
		)
		interactor.setOutput(presenter)
		view.output = presenter
		return view
	}
}

