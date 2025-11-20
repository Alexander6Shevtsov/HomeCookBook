//
//  RecipeDetailPresenter.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

final class RecipeDetailPresenter {
	
	private weak var view: RecipeDetailViewInput?
	private let interactor: RecipeDetailInteractorInput
	private let router: RecipeDetailRouterInput
	private let mealId: String
	
	init(
		view: RecipeDetailViewInput,
		interactor: RecipeDetailInteractorInput,
		router: RecipeDetailRouterInput,
		mealId: String
	) {
		self.view = view
		self.interactor = interactor
		self.router = router
		self.mealId = mealId
	}
}

extension RecipeDetailPresenter: RecipeDetailViewOutput {
	func viewDidLoad() {
		view?.showLoading(true)
		interactor.loadDetails()
	}
}

extension RecipeDetailPresenter: RecipeDetailInteractorOutput {
	func didLoad(details: RecipeDetailEntity) {
		view?.showLoading(false)
		view?.display(title: details.title, imageURL: details.imageURL, instructions: details.instructions)
	}
	
	func didFailToLoad(error: Error) {
		view?.showLoading(false)
		view?.showError(message: error.localizedDescription)
	}
}

