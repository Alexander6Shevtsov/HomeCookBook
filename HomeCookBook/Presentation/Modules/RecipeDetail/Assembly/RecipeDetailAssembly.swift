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
		
		let networkClient = URLSessionNetworkClient()
		let service = TheMealDBService(client: networkClient)
		let interactor = RecipeDetailInteractor(mealId: mealId, service: service, output: nil)
		
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

