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
		
		let interactor = RecipeDetailInteractor(mealId: mealId, service: service)
		let presenter = RecipeDetailPresenter(
			view: view,
			interactor: interactor
		)
		interactor.setOutput(presenter)
		view.output = presenter
		return view
	}
}

