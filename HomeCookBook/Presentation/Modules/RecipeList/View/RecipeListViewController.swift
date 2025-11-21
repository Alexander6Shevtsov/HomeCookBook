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
	
	private let collectionView: UICollectionView
	private let searchController = UISearchController(searchResultsController: nil)
	
	private var items: [RecipeListItemViewModel] = []
	
	private let imageLoader = ImageLoader.shared
	private var imageTasks: [IndexPath: Task<Void, Never>] = [:]
	
	private let stateView = StateOverlayView()
	
	private enum Constants {
		static let sectionInset: CGFloat = 16
		static let interItemSpacing: CGFloat = 12
		static let lineSpacing: CGFloat = 16
		
		static let imageAspectRatio: CGFloat = 0.75
		static let contentPadding: CGFloat = 10
		static let labelsSpacing: CGFloat = 4
		
		static let titleLines = 2
		static let subtitleLines = 1
		static let titleFont = UIFont.preferredFont(forTextStyle: .headline)
		static let subtitleFont = UIFont.preferredFont(forTextStyle: .subheadline)
		
		static let title = "Recipes"
		
		static let prefetchThreshold = 12
	}
	
	init() {
		let layout = UICollectionViewFlowLayout()
		layout.minimumInteritemSpacing = Constants.interItemSpacing
		layout.minimumLineSpacing = Constants.lineSpacing
		layout.sectionInset = UIEdgeInsets(
			top: Constants.sectionInset,
			left: Constants.sectionInset,
			bottom: Constants.sectionInset,
			right: Constants.sectionInset
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
	}
	
	private func setupUI() {
		view.backgroundColor = .systemBackground
		title = Constants.title
		navigationItem.largeTitleDisplayMode = .always
		
		searchController.searchResultsUpdater = self
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.autocapitalizationType = .none
		searchController.searchBar.placeholder = "Search recipes"
		navigationItem.searchController = searchController
		definesPresentationContext = true
		
		let favoritesButton = UIBarButtonItem(
			image: UIImage(systemName: "star"),
			style: .plain,
			target: self,
			action: #selector(didTapFavorites)
		)
		favoritesButton.accessibilityLabel = "Favorites"
		navigationItem.rightBarButtonItem = favoritesButton
		
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
	
	@objc private func didTapFavorites() {
		output?.showFavorites()
	}
	
	private func setupFavorites() {
		guard let favoritesStore else {
			assertionFailure("favoritesStore must be injected via assembly before viewDidLoad")
			return
		}
		
		Task { [weak self] in
			guard let self else { return }
			do {
				let items = try await favoritesStore.fetchAll()
				let ids = Set(items.map(\.id))
				await MainActor.run {
					let oldIDs = self.favoriteIDs
					self.favoriteIDs = ids
					guard !self.items.isEmpty else { return }
					let changed = oldIDs.symmetricDifference(ids)
					let indexPaths = self.items.enumerated().compactMap { offset, vm in
						changed.contains(vm.id) ? IndexPath(item: offset, section: 0) : nil
					}
					if !indexPaths.isEmpty {
						self.collectionView.reloadItems(at: indexPaths)
					}
				}
			} catch {
			}
		}
		
		favoritesObserver = NotificationCenter.default.addObserver(
			forName: .favoritesDidChange,
			object: nil,
			queue: .main
		) { [weak self] _ in
			guard let self else { return }
			Task { [weak self] in
				guard let self else { return }
				do {
					let items = try await favoritesStore.fetchAll()
					let ids = Set(items.map(\.id))
					await MainActor.run {
						let oldIDs = self.favoriteIDs
						self.favoriteIDs = ids
						guard !self.items.isEmpty else { return }
						let changed = oldIDs.symmetricDifference(ids)
						let indexPaths = self.items.enumerated().compactMap { offset, vm in
							changed.contains(vm.id) ? IndexPath(item: offset, section: 0) : nil
						}
						if !indexPaths.isEmpty {
							self.collectionView.reloadItems(at: indexPaths)
						}
					}
				} catch { }
			}
		}
	}
	
	private func columns(for width: CGFloat) -> Int {
		if traitCollection.horizontalSizeClass == .regular && width > 700 { return 3 }
		return 2
	}
	
	private func itemSize(for width: CGFloat) -> CGSize {
		let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
		let sectionInsets = layout?.sectionInset ?? .zero
		let inter = layout?.minimumInteritemSpacing ?? Constants.interItemSpacing
		
		let cols = CGFloat(columns(for: width))
		let totalHSpacing = sectionInsets.left + sectionInsets.right + inter * max(0, cols - 1)
		let itemWidth = max(0, (width - totalHSpacing) / cols)
		
		let imageHeight = itemWidth * Constants.imageAspectRatio
		let titleHeight = Constants.titleFont.lineHeight * CGFloat(Constants.titleLines)
		let subtitleHeight = Constants.subtitleFont.lineHeight * CGFloat(Constants.subtitleLines)
		let verticalTextSpacing = Constants.contentPadding + Constants.labelsSpacing + Constants.contentPadding
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
			symbolName: "magnifyingglass",
			title: "No Results",
			message: "Try another query or clear the search.",
			buttonTitle: nil
		)
	}
	
	private func showErrorState(message: String) {
		stateView.isHidden = false
		stateView.configure(
			symbolName: "exclamationmark.triangle",
			title: "Something went wrong",
			message: message,
			buttonTitle: "Retry"
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
		let preheatRows = rowsOnScreen + 2
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
			assertionFailure("Unexpected cell type for reuse id: \(RecipeCardCell.reuseId)")
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
							visibleCell.configure(title: vm.title, subtitle: vm.subtitle, isFavorite: nowFavorite)
						}
					}
				} catch {
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
		output?.didSelectItem(at: indexPath.item)
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
		   maxIndex >= max(0, items.count - Constants.prefetchThreshold) {
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
}

extension RecipeListViewController: UISearchResultsUpdating {
	func updateSearchResults(for searchController: UISearchController) {
		let text = searchController.searchBar.text ?? ""
		output?.search(query: text)
	}
}

private final class StateOverlayView: UIView {
	var onRetry: (() -> Void)?
	
	private let stack = UIStackView()
	private let symbolView = UIImageView()
	private let titleLabel = UILabel()
	private let messageLabel = UILabel()
	private let retryButton = UIButton(type: .system)
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}
	
	private func setup() {
		backgroundColor = .systemBackground
		
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .vertical
		stack.alignment = .center
		stack.spacing = 12
		
		symbolView.translatesAutoresizingMaskIntoConstraints = false
		symbolView.tintColor = .tertiaryLabel
		symbolView.contentMode = .scaleAspectFit
		
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
		titleLabel.textColor = .label
		titleLabel.numberOfLines = 0
		titleLabel.textAlignment = .center
		
		messageLabel.translatesAutoresizingMaskIntoConstraints = false
		messageLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
		messageLabel.textColor = .secondaryLabel
		messageLabel.numberOfLines = 0
		messageLabel.textAlignment = .center
		
		retryButton.translatesAutoresizingMaskIntoConstraints = false
		retryButton.setTitle("Retry", for: .normal)
		retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
		
		addSubview(stack)
		stack.addArrangedSubview(symbolView)
		stack.addArrangedSubview(titleLabel)
		stack.addArrangedSubview(messageLabel)
		stack.addArrangedSubview(retryButton)
		
		NSLayoutConstraint.activate([
			stack.centerXAnchor.constraint(equalTo: centerXAnchor),
			stack.centerYAnchor.constraint(equalTo: centerYAnchor),
			stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
			stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
			
			symbolView.widthAnchor.constraint(equalToConstant: 48),
			symbolView.heightAnchor.constraint(equalToConstant: 48)
		])
	}
	
	func configure(symbolName: String, title: String, message: String, buttonTitle: String?) {
		let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
		symbolView.image = UIImage(systemName: symbolName, withConfiguration: config)
		
		titleLabel.text = title
		messageLabel.text = message
		
		if let title = buttonTitle, !title.isEmpty {
			retryButton.isHidden = false
			retryButton.setTitle(title, for: .normal)
		} else {
			retryButton.isHidden = true
		}
	}
	
	@objc private func didTapRetry() {
		onRetry?()
	}
}
