//
//  RecipeDetailContracts.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

protocol RecipeDetailViewInput: AnyObject {
	func display(title: String, imageURL: URL?, instructions: String)
	
	func showLoading(_ isLoading: Bool)
	
	func showError(message: String)
}

protocol RecipeDetailViewOutput: AnyObject {
	func viewDidLoad()
}

protocol RecipeDetailInteractorInput: AnyObject {
	func loadDetails()
}

protocol RecipeDetailInteractorOutput: AnyObject {
	func didLoad(details: RecipeDetailEntity)
	func didFailToLoad(error: Error)
}

protocol RecipeDetailRouterInput: AnyObject { }

struct RecipeDetailEntity {
	let id: String
	let title: String
	let imageURL: URL?
	let instructions: String
}

