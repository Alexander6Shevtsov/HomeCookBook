//
//  MealLookupDTO.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

struct MealLookupResponseDTO: Decodable {
	let meals: [MealDetailDTO]?
}

struct MealDetailDTO: Decodable {
	let idMeal: String
	let strMeal: String
	let strMealThumb: String?
	let strInstructions: String?
}
