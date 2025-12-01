//
//  RecipeListCollectionController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 01.12.2025.
//

import UIKit

final class RecipeListCollectionController: NSObject {
	private let collectionView: UICollectionView
	private let layoutCalculator: RecipeListLayoutCalculator
	private let imageLoader: ImageLoader
	
	private var items: [RecipeListItemViewModel] = []
	private var favoriteIDs: Set<String> = []
	private var imageTasks: [IndexPath: Task<Void, Never>] = [:]
	
	var onLoadMore: (() -> Void)?
	var onSelectItem: ((Int, UIImage?) -> Void)?
	var onToggleFavorite: ((RecipeListItemViewModel, IndexPath) -> Void)?
	
	private struct Behavior {
		static let prefetchThreshold = 12
		static let preheatExtraRows = 2
	}
	
	init(
		collectionView: UICollectionView,
		layoutCalculator: RecipeListLayoutCalculator,
		imageLoader: ImageLoader = .shared
	) {
		self.collectionView = collectionView
		self.layoutCalculator = layoutCalculator
		self.imageLoader = imageLoader
		super.init()
		configureCollectionView()
	}
	
	deinit {
		cancelAllImageTasks()
		Task { [imageLoader] in
			await imageLoader.cancelAllPrefetches()
		}
	}
	
	func setItems(_ newItems: [RecipeListItemViewModel]) {
		let oldItems = items
		let oldCount = oldItems.count
		let newCount = newItems.count
		let isAppend =
		oldCount > 0 &&
		newCount >= oldCount &&
		zip(oldItems, newItems.prefix(oldCount)).allSatisfy { $0.id == $1.id }
		
		if isAppend {
			items = newItems
			let insertRange = oldCount..<newCount
			let indexPaths = insertRange.map { IndexPath(item: $0, section: 0) }
			collectionView.performBatchUpdates({
				collectionView.insertItems(at: indexPaths)
			}, completion: nil)
		} else {
			cancelAllImageTasks()
			items = newItems
			collectionView.reloadData()
			preheatInitialImages()
		}
	}
	
	func setFavoriteIDs(_ favoriteIdSet: Set<String>) {
		favoriteIDs = favoriteIdSet
		collectionView.reloadData()
	}
	
	func applyFavoriteChange(id: String, isFavorite: Bool) {
		if isFavorite {
			favoriteIDs.insert(id)
		} else {
			favoriteIDs.remove(id)
		}
		if let index = items.firstIndex(where: { $0.id == id }) {
			let indexPath = IndexPath(item: index, section: 0)
			if let cell = collectionView.cellForItem(at: indexPath) as? RecipeCardCell {
				cell.setFavorite(isFavorite)
			}
		}
	}
	
	private func configureCollectionView() {
		collectionView.dataSource = self
		collectionView.delegate = self
		collectionView.prefetchDataSource = self
		collectionView.backgroundColor = .clear
		collectionView.register(
			RecipeCardCell.self,
			forCellWithReuseIdentifier: RecipeCardCell.reuseIdentifier
		)
	}
	
	private func cancelAllImageTasks() {
		imageTasks.values.forEach { $0.cancel() }
		imageTasks.removeAll()
	}
	
	private func preheatInitialImages() {
		guard items.isEmpty == false else { return }
		let width = collectionView.bounds.width
		let sectionInsets = (
			collectionView.collectionViewLayout as? UICollectionViewFlowLayout
		)?.sectionInset ?? .zero
		let interItem = (
			collectionView.collectionViewLayout as? UICollectionViewFlowLayout
		)?.minimumInteritemSpacing ?? RecipeListLayoutCalculator.Constants.interItemSpacing
		let itemSize = layoutCalculator.itemSize(
			containerWidth: width,
			sectionInsets: sectionInsets,
			interItemSpacing: interItem
		)
		let columnsCount = layoutCalculator.columnsCount()
		let rowsOnScreen = max(1, Int(ceil(collectionView.bounds.height / itemSize.height)))
		let preheatRows = rowsOnScreen + Behavior.preheatExtraRows
		let itemsToPreheatCount = min(items.count, preheatRows * columnsCount)
		let urls = (0..<itemsToPreheatCount).compactMap { items[$0].thumbnailURL }
		if urls.isEmpty == false {
			Task { await imageLoader.prefetch(urls: urls) }
		}
	}
}

extension RecipeListCollectionController: UICollectionViewDataSource {
	func collectionView(
		_ collectionView: UICollectionView,
		numberOfItemsInSection section: Int
	) -> Int {
		items.count
	}
	
	func collectionView(
		_ collectionView: UICollectionView,
		cellForItemAt indexPath: IndexPath
	) -> UICollectionViewCell {
		let dequeuedCell = collectionView.dequeueReusableCell(
			withReuseIdentifier: RecipeCardCell.reuseIdentifier,
			for: indexPath
		)
		guard let cell = dequeuedCell as? RecipeCardCell else {
			return dequeuedCell
		}
		
		let itemViewModel = items[indexPath.item]
		let isFavorite = favoriteIDs.contains(itemViewModel.id)
		cell.configure(
			title: itemViewModel.title,
			subtitle: itemViewModel.subtitle,
			isFavorite: isFavorite
		)
		
		imageTasks[indexPath]?.cancel()
		imageTasks[indexPath] = nil
		
		cell.onToggleFavorite = { [weak self] in
			guard let self else { return }
			self.onToggleFavorite?(itemViewModel, indexPath)
		}
		
		guard let url = itemViewModel.thumbnailURL else {
			cell.setPlaceholder()
			return cell
		}
		
		if let cached = imageLoader.cachedImage(for: url) {
			cell.setImage(cached)
			return cell
		}
		
		cell.setPlaceholder()
		let expectedId = itemViewModel.id
		let task = Task { [weak self, weak collectionView] in
			guard let self else { return }
			if let image = try? await self.imageLoader.image(from: url) {
				await MainActor.run {
					guard
						let collectionView,
						let visibleCell = collectionView.cellForItem(
							at: indexPath
						) as? RecipeCardCell
					else {
						self.imageTasks[indexPath] = nil
						return
					}
					guard indexPath.item < self.items.count,
						  self.items[indexPath.item].id == expectedId else {
						self.imageTasks[indexPath] = nil
						return
					}
					visibleCell.setImage(image)
					self.imageTasks[indexPath] = nil
				}
			} else {
				await MainActor.run { [weak self] in
					self?.imageTasks[indexPath] = nil
				}
			}
		}
		imageTasks[indexPath] = task
		
		return cell
	}
}

extension RecipeListCollectionController: UICollectionViewDelegate {
	func collectionView(
		_ collectionView: UICollectionView,
		didSelectItemAt indexPath: IndexPath
	) {
		let itemViewModel = items[indexPath.item]
		let previewImage = itemViewModel.thumbnailURL.flatMap {
			imageLoader.cachedImage(for: $0)
		}
		onSelectItem?(indexPath.item, previewImage)
		collectionView.deselectItem(at: indexPath, animated: true)
	}
	
	func collectionView(
		_ collectionView: UICollectionView,
		didEndDisplaying cell: UICollectionViewCell,
		forItemAt indexPath: IndexPath
	) {
		imageTasks[indexPath]?.cancel()
		imageTasks[indexPath] = nil
	}
}

extension RecipeListCollectionController: UICollectionViewDelegateFlowLayout {
	func collectionView(
		_ collectionView: UICollectionView,
		layout collectionViewLayout: UICollectionViewLayout,
		sizeForItemAt indexPath: IndexPath
	) -> CGSize {
		let sectionInsets = (
			collectionViewLayout as? UICollectionViewFlowLayout
		)?.sectionInset ?? .zero
		let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout
		let interItem = flowLayout?.minimumInteritemSpacing
		?? RecipeListLayoutCalculator.Constants.interItemSpacing
		return layoutCalculator.itemSize(
			containerWidth: collectionView.bounds.width,
			sectionInsets: sectionInsets,
			interItemSpacing: interItem
		)
	}
}

extension RecipeListCollectionController: UICollectionViewDataSourcePrefetching {
	func collectionView(
		_ collectionView: UICollectionView,
		prefetchItemsAt indexPaths: [IndexPath]
	) {
		let urls = indexPaths.compactMap { indexPath -> URL? in
			guard indexPath.item < items.count else { return nil }
			return items[indexPath.item].thumbnailURL
		}
		guard urls.isEmpty == false else { return }
		
		Task { await imageLoader.prefetch(urls: urls) }
		
		if items.isEmpty == false {
			if let maxIndex = indexPaths.map(\.item).max(),
			   maxIndex >= max(0, items.count - Behavior.prefetchThreshold) {
				onLoadMore?()
			}
		}
	}
	
	func collectionView(
		_ collectionView: UICollectionView,
		cancelPrefetchingForItemsAt indexPaths: [IndexPath]
	) {
		let urls = indexPaths.compactMap { indexPath -> URL? in
			guard indexPath.item < items.count else { return nil }
			return items[indexPath.item].thumbnailURL
		}
		guard urls.isEmpty == false else { return }
		
		Task {
			for url in urls {
				await imageLoader.cancelPrefetch(url: url)
			}
		}
	}
}
