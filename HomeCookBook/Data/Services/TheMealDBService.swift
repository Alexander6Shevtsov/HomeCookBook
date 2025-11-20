//
//  TheMealDBService.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

protocol MealsService {
	func fetchInitial() async throws -> [RecipeListItemEntity]
	func fetch(query: String) async throws -> [RecipeListItemEntity]
	func fetchDetails(id: String) async throws -> RecipeDetailEntity
}

final class TheMealDBService: MealsService {
	private let client: NetworkClient
	
	init(client: NetworkClient) {
		self.client = client
	}
	
	func fetchInitial() async throws -> [RecipeListItemEntity] {
		guard let url = URL(string: "https://www.themealdb.com/api/json/v1/1/search.php?f=a") else {
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
	
	func fetch(query: String) async throws -> [RecipeListItemEntity] {
		var comps = URLComponents(string: "https://www.themealdb.com/api/json/v1/1/search.php")
		comps?.queryItems = [URLQueryItem(name: "s", value: query)]
		guard let url = comps?.url else { throw URLError(.badURL) }
		
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
	
	func fetchDetails(id: String) async throws -> RecipeDetailEntity {
		guard let url = URL(string: "https://www.themealdb.com/api/json/v1/1/lookup.php?i=\(id)") else {
			throw URLError(.badURL)
		}
		let response: MealLookupResponseDTO = try await client.get(url)
		guard let dto = response.meals?.first else {
			throw URLError(.cannotParseResponse)
		}
		return RecipeDetailEntity(
			id: dto.idMeal,
			title: dto.strMeal,
			imageURL: dto.strMealThumb.flatMap(URL.init(string:)),
			instructions: dto.strInstructions ?? ""
		)
	}
}
