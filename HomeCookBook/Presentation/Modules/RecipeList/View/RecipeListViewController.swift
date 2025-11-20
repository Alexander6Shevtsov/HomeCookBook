//
//  RecipeListViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeListViewController: UIViewController {
	
	var output: RecipeListViewOutput?
	
	private let tableView = UITableView(frame: .zero, style: .plain)
	private let refreshControl = UIRefreshControl()
	private var items: [RecipeListItemViewModel] = []
	private let imageLoader = ImageLoader.shared
	private var imageTasks: [IndexPath: Task<Void, Never>] = [:]
	
	private enum Constants {
		static let rowHeight: CGFloat = 72
		static let cellReuseId = "RecipeCell"
		static let title = "Recipes"
		static let imageSize = CGSize(width: 56, height: 56)
		static let imageCornerRadius: CGFloat = 8
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		output?.viewDidLoad()
	}
	
	private func setupUI() {
		view.backgroundColor = .systemBackground
		title = Constants.title
		navigationItem.largeTitleDisplayMode = .always
		
		tableView.translatesAutoresizingMaskIntoConstraints = false
		tableView.backgroundColor = .clear
		tableView.rowHeight = Constants.rowHeight
		tableView.separatorStyle = .singleLine
		tableView.dataSource = self
		tableView.delegate = self
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.cellReuseId)
		tableView.refreshControl = refreshControl
		
		refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
		
		view.addSubview(tableView)
		
		NSLayoutConstraint.activate([
			tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}
	
	@objc private func didPullToRefresh() {
		output?.refresh()
	}
	
	private func applyPlaceholderConfig(to cell: UITableViewCell, vm: RecipeListItemViewModel) {
		var config = cell.defaultContentConfiguration()
		config.text = vm.title
		config.secondaryText = vm.subtitle
		config.image = UIImage(systemName: "photo")
		config.imageProperties.preferredSymbolConfiguration = .init(
			pointSize: 20,
			weight: .regular
		)
		config.imageProperties.maximumSize = Constants.imageSize
		config.imageProperties.reservedLayoutSize = Constants.imageSize
		config.imageProperties.cornerRadius = Constants.imageCornerRadius
		cell.contentConfiguration = config
		cell.accessoryType = .disclosureIndicator
	}
	
	private func applyImage(_ image: UIImage, to cell: UITableViewCell, vm: RecipeListItemViewModel) {
		var config = cell.defaultContentConfiguration()
		config.text = vm.title
		config.secondaryText = vm.subtitle
		config.image = image
		config.imageProperties.maximumSize = Constants.imageSize
		config.imageProperties.reservedLayoutSize = Constants.imageSize
		config.imageProperties.cornerRadius = Constants.imageCornerRadius
		cell.contentConfiguration = config
		cell.accessoryType = .disclosureIndicator
	}
	
	private func cancelAllImageTasks() {
		imageTasks.values.forEach { $0.cancel() }
		imageTasks.removeAll()
	}
}

extension RecipeListViewController: UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		items.count
	}
	
	func tableView(
		_ tableView: UITableView,
		cellForRowAt indexPath: IndexPath
	) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(
			withIdentifier: Constants.cellReuseId,
			for: indexPath
		)
		let vm = items[indexPath.row]
		
		applyPlaceholderConfig(to: cell, vm: vm)
		
		imageTasks[indexPath]?.cancel()
		imageTasks[indexPath] = nil
		
		if let url = vm.thumbnailURL {
			let task = Task { [weak self, weak tableView] in
				guard let self else { return }
				if let image = try? await self.imageLoader.image(from: url) {
					await MainActor.run {
						guard
							let tableView,
							let visibleCell = tableView.cellForRow(at: indexPath)
						else { return }
						self.applyImage(image, to: visibleCell, vm: vm)
					}
				}
			}
			imageTasks[indexPath] = task
		}
		
		return cell
	}
}

extension RecipeListViewController: UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		output?.didSelectItem(at: indexPath.row)
		tableView.deselectRow(at: indexPath, animated: true)
	}
	
	func tableView(
		_ tableView: UITableView,
		didEndDisplaying cell: UITableViewCell,
		forRowAt indexPath: IndexPath
	) {
		imageTasks[indexPath]?.cancel()
		imageTasks[indexPath] = nil
	}
}

extension RecipeListViewController: RecipeListViewInput {
	func display(items: [RecipeListItemViewModel]) {
		cancelAllImageTasks()
		self.items = items
		tableView.reloadData()
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
			if !refreshControl.isRefreshing {
				refreshControl.beginRefreshing()
				if tableView.contentOffset.y == 0 {
					let offset = CGPoint(x: 0, y: -refreshControl.frame.size.height)
					tableView.setContentOffset(offset, animated: true)
				}
			}
		} else {
			if refreshControl.isRefreshing {
				refreshControl.endRefreshing()
			}
		}
	}
	
	func showError(message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
