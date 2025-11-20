//
//  RecipeListInteractor.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

final class RecipeListInteractor: RecipeListInteractorInput {
	
	private weak var output: RecipeListInteractorOutput?
	
	init(output: RecipeListInteractorOutput?) {
		self.output = output
	}
	
	func setOutput(_ output: RecipeListInteractorOutput) {
		self.output = output
	}
	
	func loadInitial() {
		DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) { [weak self] in
			let demo = [
				RecipeListItemEntity(id: "52772", name: "Teriyaki Chicken Casserole", category: "Chicken", thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg")),
				RecipeListItemEntity(id: "52874", name: "Beef and Mustard Pie", category: "Beef", thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/sytuqu1511553755.jpg"))
			]
			self?.output?.didLoad(items: demo)
		}
	}
}



