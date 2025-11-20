//
//  MealSearchDTO.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import Foundation

struct MealSearchResponseDTO: Decodable {
	let meals: [MealDTO]?
}

struct MealDTO: Decodable {
	let idMeal: String
	let strMeal: String
	let strCategory: String?
	let strMealThumb: String?
}
