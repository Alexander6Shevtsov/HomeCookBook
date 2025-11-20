//
//  RecipeDetailAssembly.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

enum RecipeDetailAssembly {
	static func build(mealId: String) -> UIViewController {
		let view = RecipeDetailViewController()
		let router = RecipeDetailRouter(viewController: view)
		let interactor = RecipeDetailInteractor(mealId: mealId, output: nil)
		let presenter = RecipeDetailPresenter(
			view: view,
			interactor: interactor,
			router: router,
			mealId: mealId
		)
		view.output = presenter
		interactor.setOutput(presenter)
		return view
	}
}

