//
//  RecipeListFilterMenuBuilder.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 01.12.2025.
//

import UIKit

enum RecipeListFilterMenuBuilder {
	static func initialMenu(
		allTitle: String,
		menuTitle: String,
		loadingTitle: String,
		onSelect: @escaping (String?) -> Void
	) -> UIMenu {
		let allAction = UIAction(
			title: allTitle,
			state: .on
		) { _ in
			onSelect(nil)
		}
		let loading = UIAction(
			title: loadingTitle,
			attributes: [.disabled]
		) { _ in }
		return UIMenu(
			title: menuTitle,
			options: .singleSelection,
			children: [allAction, loading]
		)
	}
	
	static func buildMenu(
		allTitle: String,
		menuTitle: String,
		categories: [String],
		selected: String?,
		onSelect: @escaping (String?) -> Void
	) -> UIMenu {
		let allAction = UIAction(
			title: allTitle,
			state: selected == nil ? .on : .off
		) { _ in
			onSelect(nil)
		}
		
		let categoryActions = categories.map { category in
			UIAction(
				title: category,
				state: category == selected ? .on : .off
			) { _ in
				onSelect(category)
			}
		}
		
		return UIMenu(
			title: menuTitle,
			options: .singleSelection,
			children: [allAction] + categoryActions
		)
	}
}
