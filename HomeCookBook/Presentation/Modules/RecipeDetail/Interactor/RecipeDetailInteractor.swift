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
	
	init(mealId: String, output: RecipeDetailInteractorOutput?) {
		self.mealId = mealId
		self.output = output
	}
	
	func setOutput(_ output: RecipeDetailInteractorOutput) {
		self.output = output
	}
	
	func loadDetails() {
		DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) { [weak self] in
			guard let self else { return }
			let demo = RecipeDetailEntity(
				id: self.mealId,
				title: "Sample Meal \(self.mealId)",
				imageURL: URL(string: "https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg"),
				instructions: "1) Prep ingredients.\n2) Cook gently.\n3) Serve hot."
			)
			self.output?.didLoad(details: demo)
		}
	}
}

