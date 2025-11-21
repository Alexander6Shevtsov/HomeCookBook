//
//  RecipeDetailAssembly.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

enum RecipeDetailAssembly {
	static func build(
		mealId: String,
		initialTitle: String?,
		initialImageURL: URL?,
		initialImage: UIImage?,
		service: MealsService,
		favoritesStore: FavoritesStore
	) -> UIViewController {
		let view = RecipeDetailViewController()
		view.mealId = mealId
		view.favoritesStore = favoritesStore
		view.initialTitle = initialTitle
		view.initialImageURL = initialImageURL
		view.initialImage = initialImage
		
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

