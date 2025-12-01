//
//  RecipeListLayoutCalculator.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 01.12.2025.
//

import UIKit

struct RecipeListLayoutCalculator {
	struct Constants {
		static let sectionInset: CGFloat = 16
		static let interItemSpacing: CGFloat = 12
		static let lineSpacing: CGFloat = 16
		static let imageAspectRatio: CGFloat = 0.75
		static let contentPadding: CGFloat = 10
		static let labelsSpacing: CGFloat = 4
		static let titleLines = 2
		static let subtitleLines = 1
	}
	
	static func makeLayout() -> UICollectionViewFlowLayout {
		let layout = UICollectionViewFlowLayout()
		layout.minimumInteritemSpacing = Constants.interItemSpacing
		layout.minimumLineSpacing = Constants.lineSpacing
		layout.sectionInset = UIEdgeInsets(
			top: Constants.sectionInset,
			left: Constants.sectionInset,
			bottom: Constants.sectionInset,
			right: Constants.sectionInset
		)
		return layout
	}
	
	func columns(forWidth width: CGFloat) -> Int {
		return 2
	}
	
	func itemSize(
		containerWidth: CGFloat,
		sectionInsets: UIEdgeInsets,
		interItemSpacing: CGFloat
	) -> CGSize {
		let columnsCount = CGFloat(columns(forWidth: containerWidth))
		let totalHorizontalSpacing =
		sectionInsets.left
		+ sectionInsets.right
		+ interItemSpacing * max(0, columnsCount - 1)
		
		let itemWidth = max(0, (containerWidth - totalHorizontalSpacing) / columnsCount)
		let imageHeight = itemWidth * Constants.imageAspectRatio
		
		let titleLineHeight = UIFont.preferredFont(forTextStyle: .headline).lineHeight
		let subtitleLineHeight = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
		let titleHeight = titleLineHeight * CGFloat(Constants.titleLines)
		let subtitleHeight = subtitleLineHeight * CGFloat(Constants.subtitleLines)
		let verticalTextSpacing =
		Constants.contentPadding
		+ Constants.labelsSpacing
		+ Constants.contentPadding
		
		let itemHeight = imageHeight + titleHeight + subtitleHeight + verticalTextSpacing
		return CGSize(width: floor(itemWidth), height: ceil(itemHeight))
	}
}
