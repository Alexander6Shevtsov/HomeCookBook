//
//  RecipeListPresenter.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation
import UIKit

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
		case category(String)
	}
	private var lastAction: LastAction = .initial
	
	private var selectedCategory: String?
	
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
	
	private func resetPagination(with newViewModels: [RecipeListItemViewModel]) {
		allViewModels = newViewModels
		let firstSlice = Array(newViewModels.prefix(pageSize))
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
		interactor.loadInitial()
	}
	
	func didSelectItem(at index: Int, previewImage: UIImage?) {
		guard index >= 0, index < viewModels.count else { return }
		let vm = viewModels[index]
		router.routeToDetails(
			mealId: vm.id,
			initialTitle: vm.title,
			initialImageURL: vm.thumbnailURL,
			initialImage: previewImage
		)
	}
	
	func refresh() {
		selectedCategory = nil
		lastAction = .refresh
		hasMoreServerData = true
		interactor.refresh()
	}
	
	func search(query: String) {
		selectedCategory = nil
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		
		searchTask?.cancel()
		searchTask = nil
		
		guard !trimmed.isEmpty else {
			lastAction = .initial
			hasMoreServerData = true
			interactor.loadInitial()
			return
		}
		
		searchTask = Task { [weak self] in
			try? await Task.sleep(nanoseconds: 350_000_000)
			guard let self, !Task.isCancelled else { return }
			self.lastAction = .search(trimmed)
			self.hasMoreServerData = false
			self.interactor.search(query: trimmed)
		}
	}
	
	func retry() {
		switch lastAction {
		case .initial:
			hasMoreServerData = true
			interactor.loadInitial()
		case .refresh:
			hasMoreServerData = true
			interactor.refresh()
		case .search(let q):
			hasMoreServerData = false
			interactor.search(query: q)
		case .category(let c):
			hasMoreServerData = false
			interactor.searchCategory(c)
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
		case .search, .category:
			return
		case .initial, .refresh:
			guard hasMoreServerData else { return }
			isLoadingMore = true
			interactor.loadMoreNextLetter()
		}
	}
	
	func showFavorites() {
		router.routeToFavorites()
	}
	
	func requestCategories() {
		interactor.fetchCategories()
	}
	
	func selectCategory(_ name: String?) {
		selectedCategory = name
		if let name {
			lastAction = .category(name)
			hasMoreServerData = false
			interactor.searchCategory(name)
		} else {
			lastAction = .initial
			hasMoreServerData = true
			interactor.loadInitial()
		}
	}
}

extension RecipeListPresenter: RecipeListInteractorOutput {
	func didLoad(items: [RecipeListItemEntity]) {
		let mappedViewModels = items.map(map(entity:))
		resetPagination(with: mappedViewModels)
		
		switch lastAction {
		case .initial, .refresh:
			hasMoreServerData = true
		case .search, .category:
			hasMoreServerData = false
		}
		
		view?.display(items: viewModels)
	}
	
	func didLoadMore(items: [RecipeListItemEntity]) {
		let mappedViewModels = items.map(map(entity:))
		
		if mappedViewModels.isEmpty {
			hasMoreServerData = false
			isLoadingMore = false
			return
		}
		
		let existingIds = Set(allViewModels.map(\.id))
		let unique = mappedViewModels.filter { !existingIds.contains($0.id) }
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
		isLoadingMore = false
		view?.showError(message: error.localizedDescription)
	}
	
	func didLoadCategories(_ categories: [String]) {
		view?.showCategoryMenu(categories: categories, selected: selectedCategory)
	}
}

