//
//  RecipeListAssembly.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

enum RecipeListAssembly {
	static func build() -> UIViewController {
		let view = RecipeListViewController()
		let router = RecipeListRouter(viewController: view)

		let interactor = RecipeListInteractor(output: nil)

		let presenter = RecipeListPresenter(view: view, interactor: interactor, router: router)

		view.output = presenter
		interactor.setOutput(presenter)

		return view
	}
}

