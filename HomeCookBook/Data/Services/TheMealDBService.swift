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
	func fetch(firstLetter: Character) async throws -> [RecipeListItemEntity]
	func fetch(category: String) async throws -> [RecipeListItemEntity]
	func fetchDetails(id: String) async throws -> RecipeDetailEntity
	func fetchCategories() async throws -> [String]
	func fetchRandomSelection() async throws -> [RecipeListItemEntity]
	func fetchRandom() async throws -> RecipeListItemEntity?
}

final class TheMealDBService: MealsService {
	private let client: NetworkClient
	private let baseURL = "https://www.themealdb.com/api/json/v1/1/"
	
	init(client: NetworkClient) {
		self.client = client
	}
	
	private func mapItem(_ dto: MealDTO, category: String?) -> RecipeListItemEntity {
		RecipeListItemEntity(
			id: dto.idMeal,
			name: dto.strMeal,
			category: category ?? dto.strCategory,
			thumbnailURL: dto.strMealThumb.flatMap(URL.init(string:))
		)
	}
	
	func fetchInitial() async throws -> [RecipeListItemEntity] {
		try await fetch(firstLetter: "a")
	}
	
	func fetch(query: String) async throws -> [RecipeListItemEntity] {
		var components = URLComponents(string: baseURL + "search.php")
		components?.queryItems = [URLQueryItem(name: "s", value: query)]
		guard let url = components?.url else { throw URLError(.badURL) }
		
		let response: MealSearchResponseDTO = try await client.get(url)
		let meals = response.meals ?? []
		return meals.map { dto in
			mapItem(dto, category: nil)
		}
	}
	
	func fetch(firstLetter: Character) async throws -> [RecipeListItemEntity] {
		let letter = String(firstLetter).lowercased()
		guard let url = URL(string: baseURL + "search.php?f=\(letter)") else {
			throw URLError(.badURL)
		}
		let response: MealSearchResponseDTO = try await client.get(url)
		let meals = response.meals ?? []
		return meals.map { dto in
			mapItem(dto, category: nil)
		}
	}
	
	func fetch(category: String) async throws -> [RecipeListItemEntity] {
		var comps = URLComponents(string: baseURL + "filter.php")
		comps?.queryItems = [URLQueryItem(name: "c", value: category)]
		guard let url = comps?.url else { throw URLError(.badURL) }
		
		let response: MealFilterResponseDTO = try await client.get(url)
		let meals = response.meals ?? []
		return meals.map { dto in
			mapItem(
				MealDTO(
					idMeal: dto.idMeal,
					strMeal: dto.strMeal,
					strCategory: category,
					strMealThumb: dto.strMealThumb
				),
				category: category
			)
		}
	}
	
	func fetchDetails(id: String) async throws -> RecipeDetailEntity {
		guard let url = URL(string: baseURL + "lookup.php?i=\(id)") else {
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
	
	func fetchCategories() async throws -> [String] {
		guard let url = URL(string: baseURL + "list.php?c=list") else {
			throw URLError(.badURL)
		}
		let response: CategoryListResponseDTO = try await client.get(url)
		let items = response.meals ?? []
		return items.map { $0.strCategory }
	}
		
	func fetchRandomSelection() async throws -> [RecipeListItemEntity] {
		guard let url = URL(string: baseURL + "randomselection.php") else {
			throw URLError(.badURL)
		}
		let response: MealSearchResponseDTO = try await client.get(url)
		let meals = response.meals ?? []
		return meals.map { dto in
			mapItem(dto, category: nil)
		}
	}
	
	func fetchRandom() async throws -> RecipeListItemEntity? {
		guard let url = URL(string: baseURL + "random.php") else {
			throw URLError(.badURL)
		}
		let response: MealSearchResponseDTO = try await client.get(url)
		guard let dto = response.meals?.first else { return nil }
		return mapItem(dto, category: nil)
	}
}

private struct MealFilterResponseDTO: Decodable {
	let meals: [MealFilterItemDTO]?
}

private struct MealFilterItemDTO: Decodable {
	let idMeal: String
	let strMeal: String
	let strMealThumb: String?
}

private struct CategoryListResponseDTO: Decodable {
	let meals: [CategoryItemDTO]?
}

private struct CategoryItemDTO: Decodable {
	let strCategory: String
}
