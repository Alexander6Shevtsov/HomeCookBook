//
//  TheMealDBService.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

protocol RecipeListService {
	func fetchInitial() async throws -> [RecipeListItemEntity]
}

final class TheMealDBService: RecipeListService {
	private let client: NetworkClient
	
	init(client: NetworkClient) {
		self.client = client
	}
	
	func fetchInitial() async throws -> [RecipeListItemEntity] {
		// Пустой поиск вернет широкий список блюд
		guard let url = URL(string: "https://www.themealdb.com/api/json/v1/1/search.php?s=") else {
			throw URLError(.badURL)
		}
		let response: MealSearchResponseDTO = try await client.get(url)
		let meals = response.meals ?? []
		return meals.map { dto in
			RecipeListItemEntity(
				id: dto.idMeal,
				name: dto.strMeal,
				category: dto.strCategory,
				thumbnailURL: dto.strMealThumb.flatMap(URL.init(string:))
			)
		}
	}
}
