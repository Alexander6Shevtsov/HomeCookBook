//
//  RecipeListViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeListViewController: UIViewController {
	
	var output: RecipeListViewOutput?
	
	private let collectionView: UICollectionView
	private let refreshControl = UIRefreshControl()
	private let searchController = UISearchController(searchResultsController: nil)
	
	private var items: [RecipeListItemViewModel] = []
	
	private let imageLoader = ImageLoader.shared
	private var imageTasks: [IndexPath: Task<Void, Never>] = [:]
	
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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		output?.viewDidLoad()
	}
	
	private func setupUI() {
		view.backgroundColor = .systemBackground
		title = Constants.title
		navigationItem.largeTitleDisplayMode = .always
		
		// Search
		searchController.searchResultsUpdater = self
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.autocapitalizationType = .none
		searchController.searchBar.placeholder = "Search recipes"
		navigationItem.searchController = searchController
		definesPresentationContext = true
		
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.backgroundColor = .clear
		collectionView.dataSource = self
		collectionView.delegate = self
		collectionView.register(RecipeCardCell.self, forCellWithReuseIdentifier: RecipeCardCell.reuseId)
		
		collectionView.refreshControl = refreshControl
		refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
		
		view.addSubview(collectionView)
		NSLayoutConstraint.activate([
			collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}
	
	@objc private func didPullToRefresh() {
		output?.refresh()
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
	
	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		(collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.invalidateLayout()
	}
}

extension RecipeListViewController: UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		items.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecipeCardCell.reuseId, for: indexPath) as! RecipeCardCell
		
		let vm = items[indexPath.item]
		cell.configure(title: vm.title, subtitle: vm.subtitle)
		cell.setPlaceholder()
		
		imageTasks[indexPath]?.cancel()
		imageTasks[indexPath] = nil
		
		if let url = vm.thumbnailURL {
			let task = Task { [weak self, weak collectionView] in
				guard let self else { return }
				if let image = try? await self.imageLoader.image(from: url) {
					await MainActor.run {
						guard
							let collectionView,
							let visibleCell = collectionView.cellForItem(at: indexPath) as? RecipeCardCell
						else { return }
						visibleCell.setImage(image)
					}
				}
			}
			imageTasks[indexPath] = task
		}
		
		return cell
	}
}

extension RecipeListViewController: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		output?.didSelectItem(at: indexPath.item)
		collectionView.deselectItem(at: indexPath, animated: true)
	}
	
	func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		imageTasks[indexPath]?.cancel()
		imageTasks[indexPath] = nil
	}
}

extension RecipeListViewController: UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		itemSize(for: collectionView.bounds.width)
	}
}

extension RecipeListViewController: RecipeListViewInput {
	func display(items: [RecipeListItemViewModel]) {
		cancelAllImageTasks()
		self.items = items
		collectionView.reloadData()
	}
	
	func showLoading(_ isLoading: Bool) {
		if isLoading {
			let activity = UIActivityIndicatorView(style: .medium)
			activity.startAnimating()
			navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activity)
		} else {
			navigationItem.rightBarButtonItem = nil
		}
	}
	
	func showRefreshing(_ isRefreshing: Bool) {
		if isRefreshing {
			if !(collectionView.refreshControl?.isRefreshing ?? false) {
				collectionView.refreshControl?.beginRefreshing()
				if collectionView.contentOffset.y == 0 {
					let offset = CGPoint(x: 0, y: -(collectionView.refreshControl?.frame.size.height ?? 0))
					collectionView.setContentOffset(offset, animated: true)
				}
			}
		} else {
			if collectionView.refreshControl?.isRefreshing == true {
				collectionView.refreshControl?.endRefreshing()
			}
		}
	}
	
	func showError(message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}

extension RecipeListViewController: UISearchResultsUpdating {
	func updateSearchResults(for searchController: UISearchController) {
		let text = searchController.searchBar.text ?? ""
		output?.search(query: text)
	}
}
