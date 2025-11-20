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
	private var searchTask: Task<Void, Never>?
	
	private enum LastAction {
		case initial
		case refresh
		case search(String)
	}
	private var lastAction: LastAction = .initial
	
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
		lastAction = .initial
		view?.showLoading(true)
		interactor.loadInitial()
	}
	
	func didSelectItem(at index: Int) {
		guard index >= 0, index < viewModels.count else { return }
		let vm = viewModels[index]
		router.routeToDetails(mealId: vm.id)
	}
	
	func refresh() {
		lastAction = .refresh
		view?.showRefreshing(true)
		interactor.refresh()
	}
	
	func search(query: String) {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		
		searchTask?.cancel()
		searchTask = nil
		
		guard !trimmed.isEmpty else {
			lastAction = .initial
			view?.showLoading(true)
			interactor.loadInitial()
			return
		}
		
		searchTask = Task { [weak self] in
			try? await Task.sleep(nanoseconds: 350_000_000)
			guard let self, !Task.isCancelled else { return }
			self.lastAction = .search(trimmed)
			await MainActor.run { self.view?.showLoading(true) }
			self.interactor.search(query: trimmed)
		}
	}
	
	func retry() {
		switch lastAction {
		case .initial:
			view?.showLoading(true)
			interactor.loadInitial()
		case .refresh:
			view?.showRefreshing(true)
			interactor.refresh()
		case .search(let q):
			view?.showLoading(true)
			interactor.search(query: q)
		}
	}
}

extension RecipeListPresenter: RecipeListInteractorOutput {
	func didLoad(items: [RecipeListItemEntity]) {
		let vms = items.map(map(entity:))
		self.viewModels = vms
		view?.showLoading(false)
		view?.showRefreshing(false)
		view?.display(items: vms)
	}
	
	func didFailToLoad(error: Error) {
		view?.showLoading(false)
		view?.showRefreshing(false)
		view?.showError(message: error.localizedDescription)
	}
}
