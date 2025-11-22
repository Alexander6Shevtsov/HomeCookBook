//
//  RecipeDetailInteractor.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

final class RecipeDetailInteractor: RecipeDetailInteractorInput {
	
	private weak var output: RecipeDetailInteractorOutput?
	private let mealId: String
	private let service: MealsService
	
	init(mealId: String, service: MealsService) {
		self.mealId = mealId
		self.service = service
	}
	
	func setOutput(_ output: RecipeDetailInteractorOutput) {
		self.output = output
	}
	
	func loadDetails() {
		Task { [weak self] in
			guard let self else { return }
			do {
				let details = try await service.fetchDetails(id: mealId)
				await MainActor.run {
					self.output?.didLoad(details: details)
				}
			} catch {
				await MainActor.run {
					self.output?.didFailToLoad(error: error)
				}
			}
		}
	}
}
