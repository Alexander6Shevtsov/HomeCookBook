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
		
		let networkClient = URLSessionNetworkClient()
		let service = TheMealDBService(client: networkClient)
		
		let router = RecipeListRouter(viewController: view, service: service)
		let interactor = RecipeListInteractor(output: nil, service: service)
		
		let presenter = RecipeListPresenter(view: view, interactor: interactor, router: router)
		
		view.output = presenter
		interactor.setOutput(presenter)
		
		return view
	}
}
