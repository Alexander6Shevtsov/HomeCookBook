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
	private var favoritesObserver: RecipeListFavoritesObserver?
	
	private let collectionView: UICollectionView
	private var collectionController: RecipeListCollectionController?
	private let layoutCalculator = RecipeListLayoutCalculator()
	
	private let searchController = UISearchController(searchResultsController: nil)
	
	private let stateView = StateOverlayView()
	
	private var filterButton: UIBarButtonItem?
	
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
	
	init(favoritesStore: FavoritesStoreProtocol) {
		let layout = RecipeListLayoutCalculator.makeLayout()
		self.collectionView = UICollectionView(
			frame: .zero,
			collectionViewLayout: layout
		)
		self.favoritesStore = favoritesStore
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		return nil
	}
	
	deinit {
		favoritesObserver?.stop()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupCollectionController()
		setupFavorites()
		output?.viewDidLoad()
		output?.requestCategories()
	}
	
	private func setupUI() {
		view.backgroundColor = .systemBackground
		title = TextConstants.title
		navigationItem.largeTitleDisplayMode = .never
		
		searchController.searchResultsUpdater = self
		searchController.searchBar.delegate = self
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.autocapitalizationType = .none
		searchController.searchBar.placeholder = TextConstants.searchPlaceholder
		navigationItem.searchController = searchController
		definesPresentationContext = true
		
		let initialMenu = RecipeListFilterMenuBuilder.initialMenu(
			allTitle: TextConstants.allTitle,
			menuTitle: TextConstants.categoryMenuTitle,
			loadingTitle: TextConstants.loadingTitle
		) { [weak self] selected in
			self?.handleCategorySelection(selected)
		}
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
	
	private func setupCollectionController() {
		let controller = RecipeListCollectionController(
			collectionView: collectionView,
			layoutCalculator: layoutCalculator
		)
		controller.onLoadMore = { [weak self] in
			self?.output?.loadMore()
		}
		controller.onSelectItem = { [weak self] index, preview in
			self?.output?.didSelectItem(at: index, previewImage: preview)
		}
		controller.onToggleFavorite = { [weak self] itemViewModel, indexPath in
			self?.handleToggleFavorite(itemViewModel: itemViewModel, indexPath: indexPath)
		}
		self.collectionController = controller
	}
	
	private func setupFavorites() {
		let observer = RecipeListFavoritesObserver(
			favoritesStore: favoritesStore,
			debounceWindow: 1.0
		)
		observer.onInitialFavoritesLoaded = { [weak self] favoriteIdSet in
			self?.collectionController?.setFavoriteIDs(favoriteIdSet)
		}
		observer.onFavoriteChanged = { [weak self] id, isFavorite in
			self?.collectionController?.applyFavoriteChange(id: id, isFavorite: isFavorite)
		}
		self.favoritesObserver = observer
		observer.start()
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
	
	@objc
	private func didTapFavorites() {
		output?.showFavorites()
	}
	
	private func handleCategorySelection(_ selected: String?) {
		if let selected, selected.isEmpty == false {
			filterButton?.title = selected
			setFilterTitle(selected)
		} else {
			filterButton?.title = nil
			setFilterTitle(nil)
		}
		output?.selectCategory(selected)
	}
	
	private func handleToggleFavorite(
		itemViewModel: RecipeListItemViewModel,
		indexPath: IndexPath
	) {
		let favoriteItem = FavoriteItem(
			id: itemViewModel.id,
			title: itemViewModel.title,
			subtitle: itemViewModel.subtitle,
			thumbnailURL: itemViewModel.thumbnailURL,
			dateAdded: Date()
		)
		favoritesObserver?.markRecentlyChanged(id: itemViewModel.id)
		Task { [weak self] in
			guard let self else { return }
			do {
				let nowFavorite = try await self.favoritesStore.toggle(item: favoriteItem)
				await MainActor.run { [weak self] in
					self?.collectionController?.applyFavoriteChange(
						id: itemViewModel.id,
						isFavorite: nowFavorite
					)
				}
			} catch {
				let currentFavorite = await self.favoritesStore.isFavorite(id: itemViewModel.id)
				await MainActor.run { [weak self] in
					self?.collectionController?.applyFavoriteChange(
						id: itemViewModel.id,
						isFavorite: currentFavorite
					)
				}
			}
		}
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
}

extension RecipeListViewController: RecipeListViewInput {
	func display(items newItems: [RecipeListItemViewModel]) {
		collectionController?.setItems(newItems)
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
		let menu = RecipeListFilterMenuBuilder.buildMenu(
			allTitle: TextConstants.allTitle,
			menuTitle: TextConstants.categoryMenuTitle,
			categories: categories,
			selected: selected
		) { [weak self] selected in
			self?.handleCategorySelection(selected)
		}
		filterButton?.menu = menu
	}
}

extension RecipeListViewController: UISearchResultsUpdating {
	func updateSearchResults(for searchController: UISearchController) {
		let rawText = searchController.searchBar.text ?? ""
		output?.search(query: rawText)
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
