//
//  RecipeListViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeListViewController: UIViewController {
	
	var output: RecipeListViewOutput?
	
	var favoritesStore: FavoritesStore!
	private var favoriteIDs: Set<String> = []
	private var favoritesObserver: NSObjectProtocol?
	private var recentlyChangedFavoriteIDs: Set<String> = []
	
	private let collectionView: UICollectionView
	private let searchController = UISearchController(searchResultsController: nil)
	private var searchTask: Task<Void, Never>?
	
	private var items: [RecipeListItemViewModel] = []
	
	private let imageLoader = ImageLoader.shared
	private var imageTasks: [IndexPath: Task<Void, Never>] = [:]
	
	private let stateView = StateOverlayView()
	
	private var filterButton: UIBarButtonItem!
	
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
		static let titleTapHint = "Прокрутить к началу"
	}
	
	private enum AccessibilityConstants {
		static let filterLabel = "Filter"
		static let favoritesLabel = "Favorites"
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
		static let regularWidthThreshold: CGFloat = 700
	}
	
	init() {
		let layout = UICollectionViewFlowLayout()
		layout.minimumInteritemSpacing = LayoutConstants.interItemSpacing
		layout.minimumLineSpacing = LayoutConstants.lineSpacing
		layout.sectionInset = UIEdgeInsets(
			top: LayoutConstants.sectionInset,
			left: LayoutConstants.sectionInset,
			bottom: LayoutConstants.sectionInset,
			right: LayoutConstants.sectionInset
		)
		self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
	deinit {
		if let observer = favoritesObserver {
			NotificationCenter.default.removeObserver(observer)
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
		filterButton.accessibilityLabel = AccessibilityConstants.filterLabel
		navigationItem.leftBarButtonItem = filterButton
		
		let favoritesButton = UIBarButtonItem(
			image: UIImage(systemName: SymbolNameConstants.favoriteIcon),
			style: .plain,
			target: self,
			action: #selector(didTapFavorites)
		)
		favoritesButton.accessibilityLabel = AccessibilityConstants.favoritesLabel
		navigationItem.rightBarButtonItem = favoritesButton
		
		setFilterTitle(nil)
		
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.backgroundColor = .clear
		collectionView.dataSource = self
		collectionView.delegate = self
		collectionView.prefetchDataSource = self
		collectionView.register(RecipeCardCell.self, forCellWithReuseIdentifier: RecipeCardCell.reuseId)
		
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
	
	private func setFilterTitle(_ selected: String?) {
		navigationItem.largeTitleDisplayMode = .never
		let text = (selected?.isEmpty == false) ? selected! : TextConstants.allTitle
		navigationItem.titleView = makeTitleLabel(text: text)
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
		let tap = UITapGestureRecognizer(target: self, action: #selector(didTapTitle))
		label.addGestureRecognizer(tap)
		label.accessibilityTraits.insert(.button)
		label.accessibilityHint = TextConstants.titleTapHint
		return label
	}
	
	@objc private func didTapTitle() {
		view.endEditing(true)
		let topY = -collectionView.adjustedContentInset.top
		collectionView.setContentOffset(CGPoint(x: 0, y: topY), animated: true)
	}
	
	private func makeInitialFilterMenu() -> UIMenu {
		let allAction = UIAction(title: TextConstants.allTitle, state: .on) { [weak self] _ in
			self?.filterButton.title = nil
			self?.setFilterTitle(nil)
			self?.output?.selectCategory(nil)
		}
		let loading = UIAction(title: TextConstants.loadingTitle, attributes: [.disabled]) { _ in }
		return UIMenu(title: TextConstants.categoryMenuTitle, options: .singleSelection, children: [allAction, loading])
	}
	
	@objc private func didTapFavorites() {
		output?.showFavorites()
	}
	
	private func setupFavorites() {
		guard let favoritesStore else { return }
		
		Task { [weak self] in
			guard let self else { return }
			do {
				let items = try await favoritesStore.fetchAll()
				let ids = Set(items.map(\.id))
				await MainActor.run {
					self.favoriteIDs = ids
					self.collectionView.reloadData()
				}
			} catch {
			}
		}
		
		favoritesObserver = NotificationCenter.default.addObserver(
			forName: .favoritesDidChange,
			object: nil,
			queue: .main
		) { [weak self] note in
			guard let self else { return }
			guard
				let id = note.userInfo?[FavoritesNotification.idKey] as? String,
				let isFav = note.userInfo?[FavoritesNotification.isFavoriteKey] as? Bool
			else { return }
			
			if self.recentlyChangedFavoriteIDs.contains(id) { return }
			
			if isFav {
				self.favoriteIDs.insert(id)
			} else {
				self.favoriteIDs.remove(id)
			}
			
			if let idx = self.items.firstIndex(where: { $0.id == id }) {
				let indexPath = IndexPath(item: idx, section: 0)
				if let cell = self.collectionView.cellForItem(at: indexPath) as? RecipeCardCell {
					cell.setFavorite(isFav)
				}
			}
		}
	}
	
	private func markRecentlyChanged(_ id: String) {
		recentlyChangedFavoriteIDs.insert(id)
		DispatchQueue.main.asyncAfter(deadline: .now() + BehaviorConstants.recentlyChangedWindow) { [weak self] in
			self?.recentlyChangedFavoriteIDs.remove(id)
		}
	}
	
	private func columns(for width: CGFloat) -> Int {
		if traitCollection.horizontalSizeClass == .regular && width > BehaviorConstants.regularWidthThreshold { return 3 }
		return 2
	}
	
	private func itemSize(for width: CGFloat) -> CGSize {
		let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
		let sectionInsets = layout?.sectionInset ?? .zero
		let inter = layout?.minimumInteritemSpacing ?? LayoutConstants.interItemSpacing
		
		let cols = CGFloat(columns(for: width))
		let totalHSpacing = sectionInsets.left + sectionInsets.right + inter * max(0, cols - 1)
		let itemWidth = max(0, (width - totalHSpacing) / cols)
		
		let imageHeight = itemWidth * LayoutConstants.imageAspectRatio
		
		let titleLineHeight = UIFont.preferredFont(forTextStyle: .headline).lineHeight
		let subtitleLineHeight = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
		let titleHeight = titleLineHeight * CGFloat(LayoutConstants.titleLines)
		let subtitleHeight = subtitleLineHeight * CGFloat(LayoutConstants.subtitleLines)
		let verticalTextSpacing = LayoutConstants.contentPadding + LayoutConstants.labelsSpacing + LayoutConstants.contentPadding
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
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		coordinator.animate(alongsideTransition: { [weak self] _ in
			guard let self = self else { return }
			(self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.invalidateLayout()
		}, completion: nil)
	}
	
	private func preheatInitialImages() {
		guard !items.isEmpty else { return }
		let width = collectionView.bounds.width
		let size = itemSize(for: width)
		let cols = columns(for: width)
		let rowsOnScreen = max(1, Int(ceil(collectionView.bounds.height / size.height)))
		let preheatRows = rowsOnScreen + BehaviorConstants.preheatExtraRows
		let count = min(items.count, preheatRows * cols)
		let urls = (0..<count).compactMap { items[$0].thumbnailURL }
		guard !urls.isEmpty else { return }
		Task { await imageLoader.prefetch(urls: urls) }
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
		let dequeued = collectionView.dequeueReusableCell(
			withReuseIdentifier: RecipeCardCell.reuseId,
			for: indexPath
		)
		guard let cell = dequeued as? RecipeCardCell else {
			return dequeued
		}
		
		let vm = items[indexPath.item]
		let isFavorite = favoriteIDs.contains(vm.id)
		cell.configure(title: vm.title, subtitle: vm.subtitle, isFavorite: isFavorite)
		
		imageTasks[indexPath]?.cancel()
		imageTasks[indexPath] = nil
		
		cell.onToggleFavorite = { [weak self, weak collectionView] in
			guard let self, let favoritesStore = self.favoritesStore else { return }
			let favoriteItem = FavoriteItem(
				id: vm.id,
				title: vm.title,
				subtitle: vm.subtitle,
				thumbnailURL: vm.thumbnailURL,
				dateAdded: Date()
			)
			
			self.markRecentlyChanged(vm.id)
			
			Task { [weak self, weak collectionView] in
				guard let self else { return }
				do {
					let nowFavorite = try await favoritesStore.toggle(item: favoriteItem)
					await MainActor.run {
						if nowFavorite {
							self.favoriteIDs.insert(vm.id)
						} else {
							self.favoriteIDs.remove(vm.id)
						}
						if let collectionView,
						   let visibleCell = collectionView.cellForItem(at: indexPath) as? RecipeCardCell {
							visibleCell.setFavorite(nowFavorite)
						}
					}
				} catch {
					_ = await MainActor.run { [weak self] in
						self?.recentlyChangedFavoriteIDs.remove(vm.id)
					}
				}
			}
		}
		
		guard let url = vm.thumbnailURL else {
			cell.setPlaceholder()
			return cell
		}
		
		if let cached = imageLoader.cachedImage(for: url) {
			cell.setImage(cached)
			return cell
		}
		
		cell.setPlaceholder()
		let expectedId = vm.id
		let task = Task { [weak self, weak collectionView] in
			guard let self else { return }
			if let image = try? await self.imageLoader.image(from: url) {
				await MainActor.run {
					guard
						let collectionView,
						let visibleCell = collectionView.cellForItem(
							at: indexPath
						) as? RecipeCardCell
					else { return }
					guard indexPath.item < self.items.count, self
						.items[indexPath.item].id == expectedId else { return }
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
		let vm = items[indexPath.item]
		let preview = vm.thumbnailURL.flatMap { imageLoader.cachedImage(for: $0) }
		output?.didSelectItem(at: indexPath.item, previewImage: preview)
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
		guard !urls.isEmpty else { return }
		Task { await imageLoader.prefetch(urls: urls) }
		
		guard !items.isEmpty else { return }
		if let maxIndex = indexPaths.map(\.item).max(),
		   maxIndex >= max(0, items.count - BehaviorConstants.prefetchThreshold) {
			output?.loadMore()
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
		guard !urls.isEmpty else { return }
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
		
		let allAction = UIAction(title: TextConstants.allTitle, state: selected == nil ? .on : .off) { [weak self] _ in
			self?.filterButton.title = nil
			self?.setFilterTitle(nil)
			self?.output?.selectCategory(nil)
		}
		
		let categoryActions: [UIAction] = categories.map { cat in
			let state: UIMenuElement.State = (cat == selected) ? .on : .off
			return UIAction(title: cat, state: state) { [weak self] _ in
				self?.filterButton.title = cat
				self?.setFilterTitle(cat)
				self?.output?.selectCategory(cat)
			}
		}
		
		let menu = UIMenu(title: TextConstants.categoryMenuTitle, options: .singleSelection, children: [allAction] + categoryActions)
		filterButton.menu = menu
	}
}

extension RecipeListViewController: UISearchResultsUpdating {
	func updateSearchResults(for searchController: UISearchController) {
		let text = searchController.searchBar.text ?? ""
		searchTask?.cancel()
		if text.isEmpty {
			output?.search(query: "")
			return
		}
		let nanos = UInt64(BehaviorConstants.debounceSeconds * 1_000_000_000)
		searchTask = Task { [weak self] in
			try? await Task.sleep(nanoseconds: nanos)
			guard !Task.isCancelled else { return }
			self?.output?.search(query: text)
		}
	}
}
