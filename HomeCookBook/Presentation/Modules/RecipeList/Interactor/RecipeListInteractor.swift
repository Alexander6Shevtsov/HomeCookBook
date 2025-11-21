//
//  RecipeListInteractor.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

final class RecipeListInteractor: RecipeListInteractorInput {
	
	private weak var output: RecipeListInteractorOutput?
	private let service: MealsService
	private var currentTask: Task<Void, Never>?
	
	private let letters: [Character] = Array("abcdefghijklmnopqrstuvwxyz")
	private var currentLetterIndex: Int?
	
	init(output: RecipeListInteractorOutput?, service: MealsService) {
		self.output = output
		self.service = service
	}
	
	func setOutput(_ output: RecipeListInteractorOutput) {
		self.output = output
	}
	
	func loadInitial() {
		currentLetterIndex = 0
		startNewTask {
			let letter = self.letters[self.currentLetterIndex ?? 0]
			let items = try await self.service.fetch(firstLetter: letter)
			await MainActor.run { self.output?.didLoad(items: items) }
		}
	}
	
	func refresh() {
		currentLetterIndex = 0
		startNewTask {
			let letter = self.letters[self.currentLetterIndex ?? 0]
			let items = try await self.service.fetch(firstLetter: letter)
			await MainActor.run { self.output?.didLoad(items: items) }
		}
	}
	
	func search(query: String) {
		currentLetterIndex = nil
		startNewTask {
			let byName = try await self.service.fetch(query: query)
			if !byName.isEmpty {
				await MainActor.run { self.output?.didLoad(items: byName) }
				return
			}
			let byCategory = try await self.service.fetch(category: query)
			if !byCategory.isEmpty {
				await MainActor.run { self.output?.didLoad(items: byCategory) }
				return
			}
			let capitalized = query.capitalized
			if capitalized != query {
				let byCategoryCap = try await self.service.fetch(category: capitalized)
				await MainActor.run { self.output?.didLoad(items: byCategoryCap) }
			} else {
				await MainActor.run { self.output?.didLoad(items: []) }
			}
		}
	}
	
	func loadMoreNextLetter() {
		guard let idx = currentLetterIndex else { return }
		let next = idx + 1
		guard next < letters.count else {
			Task { @MainActor in
				self.output?.didLoadMore(items: [])
			}
			return
		}
		currentLetterIndex = next
		startNewTask {
			let letter = self.letters[next]
			let items = try await self.service.fetch(firstLetter: letter)
			await MainActor.run { self.output?.didLoadMore(items: items) }
		}
	}
	
	private func startNewTask(_ work: @escaping () async throws -> Void) {
		currentTask?.cancel()
		currentTask = Task { [weak self] in
			guard let self else { return }
			do {
				try await work()
			} catch {
				guard !Task.isCancelled else { return }
				await MainActor.run { self.output?.didFailToLoad(error: error) }
			}
		}
	}
}

