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
	
	init(output: RecipeListInteractorOutput?, service: MealsService) {
		self.output = output
		self.service = service
	}
	
	func setOutput(_ output: RecipeListInteractorOutput) {
		self.output = output
	}
	
	func loadInitial() {
		startNewTask {
			let items = try await self.service.fetchInitial()
			await MainActor.run { self.output?.didLoad(items: items) }
		}
	}
	
	func refresh() {
		startNewTask {
			let items = try await self.service.fetchInitial()
			await MainActor.run { self.output?.didLoad(items: items) }
		}
	}
	
	func search(query: String) {
		startNewTask {
			let items = try await self.service.fetch(query: query)
			await MainActor.run { self.output?.didLoad(items: items) }
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
