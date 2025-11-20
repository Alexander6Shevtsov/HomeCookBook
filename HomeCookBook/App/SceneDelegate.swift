//
//  SceneDelegate.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		guard let windowScene = scene as? UIWindowScene else { return }
		let window = UIWindow(windowScene: windowScene)
		let root = RecipeListAssembly.build()
		let nav = UINavigationController(rootViewController: root)
		nav.navigationBar.prefersLargeTitles = true 

		window.rootViewController = nav
		self.window = window
		window.makeKeyAndVisible()
	}
}

