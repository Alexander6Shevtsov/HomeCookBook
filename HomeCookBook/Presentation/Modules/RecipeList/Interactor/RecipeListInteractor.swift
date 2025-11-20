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
	
	init(output: RecipeListInteractorOutput?, service: MealsService) {
		self.output = output
		self.service = service
	}
	
	func setOutput(_ output: RecipeListInteractorOutput) {
		self.output = output
	}
	
	func loadInitial() {
		Task { [weak self] in
			guard let self else { return }
			do {
				let items = try await service.fetchInitial()
				await MainActor.run {
					self.output?.didLoad(items: items)
				}
			} catch {
				await MainActor.run {
					self.output?.didFailToLoad(error: error)
				}
			}
		}
	}
}
