//
//  RecipeDetailAssembly.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

private final class RecipeDetailInteractorInputProxy: RecipeDetailInteractorInput {
	var target: RecipeDetailInteractorInput?
	func loadDetails() {
		target?.loadDetails()
	}
}

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
		
		let interactorProxy = RecipeDetailInteractorInputProxy()
		let presenter = RecipeDetailPresenter(
			view: view,
			interactor: interactorProxy
		)
		let interactor = RecipeDetailInteractor(
			mealId: mealId,
			service: service,
			output: presenter
		)
		interactorProxy.target = interactor
		view.output = presenter
		return view
	}
}
