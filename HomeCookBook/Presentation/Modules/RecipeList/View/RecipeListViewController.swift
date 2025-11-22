//
//  RecipeListViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeListViewController: UIViewController {
	
	var output: RecipeListViewOutput?
	
	private let favoritesStore: FavoritesStoreProtocol
	private var favoriteIDs: Set<String> = []
	private var favoritesObserver: NSObjectProtocol?
	private var recentlyChangedFavoriteIDs: Set<String> = []
	
	private let collectionView: UICollectionView
	private let searchController = UISearchController(searchResultsController: nil)
	private var searchTask: Task<Void, Never>?
	private var lastSearchQuery: String = ""
	
	private var items: [RecipeListItemViewModel] = []
	
	private let imageLoader = ImageLoader.shared
	private var imageTasks: [IndexPath: Task<Void, Never>] = [:]
	
	private let stateView = StateOverlayView()
	
	private var filterButton: UIBarButtonItem?
	
	private enum LayoutConstants {
		static let sectionInset: CGFloat = 16
		static let interItemSpacing: CGFloat = 12
		static let lineSpacing: CGFloat = 16
		
		static let imageAspectRatio: CGFloat = 0.75
		static let contentPadding: CGFloat = 10
		static let labelsSpacing: CGFloat = 4
		
		static let titleLines = 2
		static let subtitleLines = 1
	}
	
	private enum TextConstants {
		static let title = "Recipes"
		static let searchPlaceholder = "Search recipes"
		static let allTitle = "All"
		static let loadingTitle = "Loading…"
		static let categoryMenuTitle = "Category"
		static let emptyTitle = "No Results"
		static let emptyMessage = "Try another query or clear the search."
		static let errorTitle = "Something went wrong"
		static let retryTitle = "Retry"
	}
	
	private enum SymbolNameConstants {
		static let filterIcon = "line.3.horizontal.decrease.circle"
		static let favoriteIcon = "star"
		static let emptySymbol = "magnifyingglass"
		static let errorSymbol = "exclamationmark.triangle"
	}
	
	private enum BehaviorConstants {
		static let prefetchThreshold = 12
		static let preheatExtraRows = 2
		static let debounceSeconds: Double = 0.3
		static let recentlyChangedWindow: TimeInterval = 1.0
	}
	
	init(favoritesStore: FavoritesStoreProtocol) {
		let layout = UICollectionViewFlowLayout()
		layout.minimumInteritemSpacing = LayoutConstants.interItemSpacing
		layout.minimumLineSpacing = LayoutConstants.lineSpacing
		layout.sectionInset = UIEdgeInsets(
			top: LayoutConstants.sectionInset,
			left: LayoutConstants.sectionInset,
			bottom: LayoutConstants.sectionInset,
			right: LayoutConstants.sectionInset
		)
		self.collectionView = UICollectionView(
			frame: .zero,
			collectionViewLayout: layout
		)
		self.favoritesStore = favoritesStore
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	deinit {
		if let observer = favoritesObserver {
			NotificationCenter.default.removeObserver(observer)
		}
		
		searchTask?.cancel()
		
		cancelAllImageTasks()
		
		Task { [imageLoader] in
			await imageLoader.cancelAllPrefetches()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupFavorites()
		output?.viewDidLoad()
		output?.requestCategories()
	}
	
	private func setupUI() {
		view.backgroundColor = .systemBackground
		title = TextConstants.title
		navigationItem.largeTitleDisplayMode = .always
		
		searchController.searchResultsUpdater = self
		searchController.searchBar.delegate = self
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.autocapitalizationType = .none
		searchController.searchBar.placeholder = TextConstants.searchPlaceholder
		navigationItem.searchController = searchController
		definesPresentationContext = true
		
		let initialMenu = makeInitialFilterMenu()
		filterButton = UIBarButtonItem(
			image: UIImage(systemName: SymbolNameConstants.filterIcon),
			menu: initialMenu
		)
		navigationItem.leftBarButtonItem = filterButton
		
		let favoritesButton = UIBarButtonItem(
			image: UIImage(systemName: SymbolNameConstants.favoriteIcon),
			style: .plain,
			target: self,
			action: #selector(didTapFavorites)
		)
		navigationItem.rightBarButtonItem = favoritesButton
		
		setFilterTitle(nil)
		
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.backgroundColor = .clear
		collectionView.dataSource = self
		collectionView.delegate = self
		collectionView.prefetchDataSource = self
		collectionView.register(
			RecipeCardCell.self,
			forCellWithReuseIdentifier: RecipeCardCell.reuseIdentifier
		)
		
		stateView.translatesAutoresizingMaskIntoConstraints = false
		stateView.isHidden = true
		stateView.onRetry = { [weak self] in
			self?.output?.retry()
		}
		
		view.addSubview(collectionView)
		view.addSubview(stateView)
		
		NSLayoutConstraint.activate([
			collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			
			stateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			stateView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			stateView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			stateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
		])
	}
	
	private func animateNavigationBar(hidden: Bool) {
		guard let navBar = navigationController?.navigationBar else { return }
		let offset: CGFloat = hidden ? -10 : 0
		let alpha: CGFloat = hidden ? 0 : 1
		
		UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
			navBar.transform = CGAffineTransform(translationX: 0, y: offset)
			navBar.alpha = alpha
		}
	}
	
	private func setFilterTitle(_ selectedCategory: String?) {
		navigationItem.largeTitleDisplayMode = .never
		
		let titleText: String
		if let selectedCategory, selectedCategory.isEmpty == false {
			titleText = selectedCategory
		} else {
			titleText = TextConstants.allTitle
		}
		
		navigationItem.titleView = makeTitleLabel(text: titleText)
	}
	
	private func makeTitleLabel(text: String) -> UILabel {
		let label = UILabel()
		label.text = text
		label.font = .preferredFont(forTextStyle: .headline)
		label.textColor = .label
		label.textAlignment = .center
		label.adjustsFontForContentSizeCategory = true
		label.adjustsFontSizeToFitWidth = true
		label.minimumScaleFactor = 0.8
		label.isUserInteractionEnabled = true
		let tapGesture = UITapGestureRecognizer(
			target: self,
			action: #selector(didTapTitle)
		)
		label.addGestureRecognizer(tapGesture)
		return label
	}
	
	@objc
	private func didTapTitle() {
		view.endEditing(true)
		let topY = -collectionView.adjustedContentInset.top
		collectionView.setContentOffset(CGPoint(x: 0, y: topY), animated: true)
	}
	
	private func makeInitialFilterMenu() -> UIMenu {
		let allAction = UIAction(
			title: TextConstants.allTitle,
			state: .on
		) { [weak self] _ in
			self?.filterButton?.title = nil
			self?.setFilterTitle(nil)
			self?.output?.selectCategory(nil)
		}
		let loading = UIAction(
			title: TextConstants.loadingTitle,
			attributes: [.disabled]
		) { _ in }
		return UIMenu(
			title: TextConstants.categoryMenuTitle,
			options: .singleSelection,
			children: [allAction, loading]
		)
	}
	
	@objc
	private func didTapFavorites() {
		output?.showFavorites()
	}
	
	private func setupFavorites() {
		Task { [weak self] in
			guard let self else { return }
			if let favoriteItems = try? await favoritesStore.fetchAll() {
				let favoriteIdentifiers = Set(favoriteItems.map(\.id))
				await MainActor.run {
					self.favoriteIDs = favoriteIdentifiers
					self.collectionView.reloadData()
				}
			}
		}
		
		favoritesObserver = NotificationCenter.default.addObserver(
			forName: .favoritesDidChange,
			object: nil,
			queue: .main
		) { [weak self] notification in
			guard let self else { return }
			guard
				let favoriteId = notification.userInfo?[FavoritesNotification.idKey] as? String,
				let isFavorite = notification.userInfo?[FavoritesNotification.isFavoriteKey] as? Bool
			else {
				return
			}
			
			if self.recentlyChangedFavoriteIDs.contains(favoriteId) {
				return
			}
			
			if isFavorite {
				self.favoriteIDs.insert(favoriteId)
			} else {
				self.favoriteIDs.remove(favoriteId)
			}
			
			if let favoriteIndex = self.items.firstIndex(where: { $0.id == favoriteId }) {
				let indexPath = IndexPath(item: favoriteIndex, section: 0)
				if let cell = self.collectionView.cellForItem(at: indexPath) as? RecipeCardCell {
					cell.setFavorite(isFavorite)
				}
			}
		}
	}
	
	private func markRecentlyChanged(_ id: String) {
		recentlyChangedFavoriteIDs.insert(id)
		Task { [weak self] in
			try? await Task.sleep(
				nanoseconds: UInt64(BehaviorConstants.recentlyChangedWindow * 1_000_000_000)
			)
			_ = await MainActor.run {
				self?.recentlyChangedFavoriteIDs.remove(id)
			}
		}
	}
	
	private func columns(for width: CGFloat) -> Int {
		return 2
	}
	
	private func itemSize(for width: CGFloat) -> CGSize {
		let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
		let sectionInsets = layout?.sectionInset ?? .zero
		let interItemSpacing = layout?.minimumInteritemSpacing ?? LayoutConstants.interItemSpacing
		
		let columnsCount = CGFloat(columns(for: width))
		let totalHorizontalSpacing =
		sectionInsets.left
		+ sectionInsets.right
		+ interItemSpacing * max(0, columnsCount - 1)
		
		let itemWidth = max(0, (width - totalHorizontalSpacing) / columnsCount)
		let imageHeight = itemWidth * LayoutConstants.imageAspectRatio
		
		let titleLineHeight = UIFont.preferredFont(forTextStyle: .headline).lineHeight
		let subtitleLineHeight = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
		let titleHeight = titleLineHeight * CGFloat(LayoutConstants.titleLines)
		let subtitleHeight = subtitleLineHeight * CGFloat(LayoutConstants.subtitleLines)
		let verticalTextSpacing =
		LayoutConstants.contentPadding
		+ LayoutConstants.labelsSpacing
		+ LayoutConstants.contentPadding
		
		let itemHeight = imageHeight + titleHeight + subtitleHeight + verticalTextSpacing
		return CGSize(width: floor(itemWidth), height: ceil(itemHeight))
	}
	
	private func cancelAllImageTasks() {
		imageTasks.values.forEach { $0.cancel() }
		imageTasks.removeAll()
	}
	
	private func showEmptyState() {
		stateView.isHidden = false
		stateView.configure(
			symbolName: SymbolNameConstants.emptySymbol,
			title: TextConstants.emptyTitle,
			message: TextConstants.emptyMessage,
			buttonTitle: nil
		)
	}
	
	private func showErrorState(message: String) {
		stateView.isHidden = false
		stateView.configure(
			symbolName: SymbolNameConstants.errorSymbol,
			title: TextConstants.errorTitle,
			message: message,
			buttonTitle: TextConstants.retryTitle
		)
	}
	
	private func hideState() {
		stateView.isHidden = true
	}
	
	private func preheatInitialImages() {
		if items.isEmpty { return }
		let width = collectionView.bounds.width
		let size = itemSize(for: width)
		let columnsCount = columns(for: width)
		let rowsOnScreen = max(1, Int(ceil(collectionView.bounds.height / size.height)))
		let preheatRows = rowsOnScreen + BehaviorConstants.preheatExtraRows
		let itemsToPreheatCount = min(items.count, preheatRows * columnsCount)
		let urls = (0..<itemsToPreheatCount).compactMap { items[$0].thumbnailURL }
		if urls.isEmpty == false {
			Task { await imageLoader.prefetch(urls: urls) }
		}
	}
}

extension RecipeListViewController: UICollectionViewDataSource {
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
		
		cell.onToggleFavorite = { [weak self, weak collectionView] in
			guard let self else { return }
			let favoritesStore = self.favoritesStore
			let favoriteItem = FavoriteItem(
				id: itemViewModel.id,
				title: itemViewModel.title,
				subtitle: itemViewModel.subtitle,
				thumbnailURL: itemViewModel.thumbnailURL,
				dateAdded: Date()
			)
			
			self.markRecentlyChanged(itemViewModel.id)
			
			Task { [weak self, weak collectionView] in
				guard let self else { return }
				do {
					let nowFavorite = try await favoritesStore.toggle(item: favoriteItem)
					_ = await MainActor.run {
						if nowFavorite {
							self.favoriteIDs.insert(itemViewModel.id)
						} else {
							self.favoriteIDs.remove(itemViewModel.id)
						}
						
						if let collectionView,
						   let visibleCell = collectionView.cellForItem(
							at: indexPath
						   ) as? RecipeCardCell {
							visibleCell.setFavorite(nowFavorite)
						}
					}
				} catch {
					_ = await MainActor.run { [weak self] in
						self?.recentlyChangedFavoriteIDs.remove(itemViewModel.id)
					}
				}
			}
		}
		
		guard let url = itemViewModel.thumbnailURL else {
			cell.setPlaceholder()
			return cell
		}
		
		if let cachedImage = imageLoader.cachedImage(for: url) {
			cell.setImage(cachedImage)
			return cell
		}
		
		cell.setPlaceholder()
		let expectedId = itemViewModel.id
		let task = Task { [weak self, weak collectionView] in
			guard let self else { return }
			if let image = try? await self.imageLoader.image(from: url) {
				_ = await MainActor.run {
					guard
						let collectionView,
						let visibleCell = collectionView.cellForItem(
							at: indexPath
						) as? RecipeCardCell
					else {
						return
					}
					
					guard indexPath.item < self.items.count,
						  self.items[indexPath.item].id == expectedId else {
						return
					}
					
					visibleCell.setImage(image)
				}
			}
		}
		imageTasks[indexPath] = task
		
		return cell
	}
}

extension RecipeListViewController: UICollectionViewDelegate {
	func collectionView(
		_ collectionView: UICollectionView,
		didSelectItemAt indexPath: IndexPath
	) {
		let itemViewModel = items[indexPath.item]
		let previewImage = itemViewModel.thumbnailURL.flatMap {
			imageLoader.cachedImage(for: $0)
		}
		output?.didSelectItem(at: indexPath.item, previewImage: previewImage)
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
	
	func collectionView(
		_ collectionView: UICollectionView,
		willDisplay cell: UICollectionViewCell,
		forItemAt indexPath: IndexPath
	) {
		if indexPath.item == items.count - 1 {
			output?.loadMore()
		}
	}
}

extension RecipeListViewController: UICollectionViewDelegateFlowLayout {
	func collectionView(
		_ collectionView: UICollectionView,
		layout collectionViewLayout: UICollectionViewLayout,
		sizeForItemAt indexPath: IndexPath
	) -> CGSize {
		itemSize(for: collectionView.bounds.width)
	}
}

extension RecipeListViewController: UICollectionViewDataSourcePrefetching {
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
			   maxIndex >= max(0, items.count - BehaviorConstants.prefetchThreshold) {
				output?.loadMore()
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

extension RecipeListViewController: RecipeListViewInput {
	func display(items newItems: [RecipeListItemViewModel]) {
		let oldItems = self.items
		let oldCount = oldItems.count
		let newCount = newItems.count
		let isAppend =
		oldCount > 0 &&
		newCount >= oldCount &&
		zip(oldItems, newItems.prefix(oldCount)).allSatisfy { $0.id == $1.id }
		
		if isAppend {
			self.items = newItems
			let insertRange = oldCount..<newCount
			let indexPaths = insertRange.map { IndexPath(item: $0, section: 0) }
			collectionView.performBatchUpdates({
				collectionView.insertItems(at: indexPaths)
			}, completion: nil)
		} else {
			cancelAllImageTasks()
			self.items = newItems
			collectionView.reloadData()
			preheatInitialImages()
		}
		
		if newItems.isEmpty {
			showEmptyState()
		} else {
			hideState()
		}
	}
	
	func showError(message: String) {
		showErrorState(message: message)
	}
	
	func showCategoryMenu(categories: [String], selected: String?) {
		setFilterTitle(selected)
		
		let allAction = UIAction(
			title: TextConstants.allTitle,
			state: selected == nil ? .on : .off
		) { [weak self] _ in
			self?.filterButton?.title = nil
			self?.setFilterTitle(nil)
			self?.output?.selectCategory(nil)
		}
		
		let categoryActions: [UIAction] = categories.map { category in
			let state: UIMenuElement.State = (category == selected) ? .on : .off
			return UIAction(title: category, state: state) { [weak self] _ in
				self?.filterButton?.title = category
				self?.setFilterTitle(category)
				self?.output?.selectCategory(category)
			}
		}
		
		let menu = UIMenu(
			title: TextConstants.categoryMenuTitle,
			options: .singleSelection,
			children: [allAction] + categoryActions
		)
		filterButton?.menu = menu
	}
}

extension RecipeListViewController: UISearchResultsUpdating {
	func updateSearchResults(for searchController: UISearchController) {
		let rawText = searchController.searchBar.text ?? ""
		let searchQuery = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
		
		searchTask?.cancel()
		searchTask = nil
		
		if searchQuery.isEmpty {
			lastSearchQuery = ""
			output?.search(query: "")
			return
		}
		
		if searchQuery == lastSearchQuery {
			return
		}
		
		lastSearchQuery = searchQuery
		
		let debounceDelayNanoseconds = UInt64(
			BehaviorConstants.debounceSeconds * 1_000_000_000
		)
		
		searchTask = Task { [weak self] in
			try? await Task.sleep(nanoseconds: debounceDelayNanoseconds)
			if Task.isCancelled { return }
			
			_ = await MainActor.run { [weak self] in
				guard let self else { return }
				self.output?.search(query: searchQuery)
			}
		}
	}
}

extension RecipeListViewController: UISearchBarDelegate {
	func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		animateNavigationBar(hidden: true)
	}
	
	func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
		animateNavigationBar(hidden: false)
	}
}
