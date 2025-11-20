//
//  RecipeDetailRouter.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeDetailRouter: RecipeDetailRouterInput {
	private weak var viewController: UIViewController?
	
	init(viewController: UIViewController) {
		self.viewController = viewController
	}
}

