//
//  RecipeListPresenter.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

final class RecipeListPresenter {
	
	private weak var view: RecipeListViewInput?
	
	private let interactor: RecipeListInteractorInput
	private let router: RecipeListRouterInput
	
	private var viewModels: [RecipeListItemViewModel] = []
	
	init(
		view: RecipeListViewInput,
		interactor: RecipeListInteractorInput,
		router: RecipeListRouterInput
	) {
		self.view = view
		self.interactor = interactor
		self.router = router
	}
	
	private func map(entity: RecipeListItemEntity) -> RecipeListItemViewModel {
		RecipeListItemViewModel(
			id: entity.id,
			title: entity.name,
			subtitle: entity.category,
			thumbnailURL: entity.thumbnailURL
		)
	}
}

extension RecipeListPresenter: RecipeListViewOutput {
	func viewDidLoad() {
		view?.showLoading(true)
		interactor.loadInitial()
	}
	
	func didSelectItem(at index: Int) {
		guard index >= 0, index < viewModels.count else { return }
		let vm = viewModels[index]
		router.routeToDetails(mealId: vm.id)
	}
}

extension RecipeListPresenter: RecipeListInteractorOutput {
	func didLoad(items: [RecipeListItemEntity]) {
		let vms = items.map(map(entity:))
		self.viewModels = vms
		view?.showLoading(false)
		view?.display(items: vms)
	}
	
	func didFailToLoad(error: Error) {
		view?.showLoading(false)
		view?.showError(message: error.localizedDescription)
	}
}

