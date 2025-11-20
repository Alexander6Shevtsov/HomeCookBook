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
	private var allViewModels: [RecipeListItemViewModel] = []
	private var searchTask: Task<Void, Never>?
	
	private let pageSize: Int = 20
	private var isLoadingMore: Bool = false
	private var hasMoreServerData: Bool = true
	
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
	
	private func resetPagination(with vms: [RecipeListItemViewModel]) {
		allViewModels = vms
		let firstSlice = Array(vms.prefix(pageSize))
		viewModels = firstSlice
	}
	
	private var canLoadMore: Bool {
		return viewModels.count < allViewModels.count
	}
}

extension RecipeListPresenter: RecipeListViewOutput {
	func viewDidLoad() {
		lastAction = .initial
		hasMoreServerData = true
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
		hasMoreServerData = true
		view?.showRefreshing(true)
		interactor.refresh()
	}
	
	func search(query: String) {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		
		searchTask?.cancel()
		searchTask = nil
		
		guard !trimmed.isEmpty else {
			lastAction = .initial
			hasMoreServerData = true
			view?.showLoading(true)
			interactor.loadInitial()
			return
		}
		
		searchTask = Task { [weak self] in
			try? await Task.sleep(nanoseconds: 350_000_000)
			guard let self, !Task.isCancelled else { return }
			self.lastAction = .search(trimmed)
			self.hasMoreServerData = false
			await MainActor.run { self.view?.showLoading(true) }
			self.interactor.search(query: trimmed)
		}
	}
	
	func retry() {
		switch lastAction {
		case .initial:
			hasMoreServerData = true
			view?.showLoading(true)
			interactor.loadInitial()
		case .refresh:
			hasMoreServerData = true
			view?.showRefreshing(true)
			interactor.refresh()
		case .search(let q):
			hasMoreServerData = false
			view?.showLoading(true)
			interactor.search(query: q)
		}
	}
	
	func loadMore() {
		guard !isLoadingMore else { return }
		
		if canLoadMore {
			isLoadingMore = true
			let currentCount = viewModels.count
			let total = allViewModels.count
			let nextEnd = min(currentCount + pageSize, total)
			
			if currentCount < nextEnd {
				let newSlice = allViewModels[currentCount..<nextEnd]
				viewModels.append(contentsOf: newSlice)
				view?.display(items: viewModels)
			}
			
			isLoadingMore = false
			return
		}
		
		switch lastAction {
		case .search:
			return
		case .initial, .refresh:
			guard hasMoreServerData else { return }
			isLoadingMore = true
			interactor.loadMoreNextLetter()
		}
	}
}

extension RecipeListPresenter: RecipeListInteractorOutput {
	func didLoad(items: [RecipeListItemEntity]) {
		let vms = items.map(map(entity:))
		resetPagination(with: vms)
		
		switch lastAction {
		case .initial, .refresh:
			hasMoreServerData = true
		case .search:
			hasMoreServerData = false
		}
		
		view?.showLoading(false)
		view?.showRefreshing(false)
		view?.display(items: viewModels)
	}
	
	func didLoadMore(items: [RecipeListItemEntity]) {
		let vms = items.map(map(entity:))
		
		if vms.isEmpty {
			hasMoreServerData = false
			isLoadingMore = false
			return
		}
		
		let existingIds = Set(allViewModels.map(\.id))
		let unique = vms.filter { !existingIds.contains($0.id) }
		allViewModels.append(contentsOf: unique)
		
		let currentCount = viewModels.count
		let nextEnd = min(currentCount + pageSize, allViewModels.count)
		if currentCount < nextEnd {
			let newSlice = allViewModels[currentCount..<nextEnd]
			viewModels.append(contentsOf: newSlice)
			view?.display(items: viewModels)
		}
		
		isLoadingMore = false
	}
	
	func didFailToLoad(error: Error) {
		view?.showLoading(false)
		view?.showRefreshing(false)
		isLoadingMore = false
		view?.showError(message: error.localizedDescription)
	}
}

