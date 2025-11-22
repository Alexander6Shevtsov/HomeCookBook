//
//  FavoritesListViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 21.11.2025.
//

import UIKit

private enum Constants {
	static let iconSize: CGFloat = 40
	static let iconCornerRadius: CGFloat = 6
	static let recentlyChangedWindow: TimeInterval = 1.0
	static let placeholderIcon = "photo"
	static let deleteTitle = "Delete"
	static let favoritesTitle = "Favorites"
	static let iconSizeCGSize = CGSize(width: iconSize, height: iconSize)
}

final class FavoritesListViewController: UIViewController {
	
	private let favoritesStore: FavoritesStore
	var onSelect: ((String, String?, URL?) -> Void)?
	
	private var items: [FavoriteItem] = []
	private let tableView = UITableView(frame: .zero, style: .insetGrouped)
	private var favoritesObserver: NSObjectProtocol?
	private var recentlyChangedFavoriteIDs: Set<String> = []
	
	private let imageLoader = ImageLoader.shared
	private var imageTasks: [IndexPath: Task<Void, Never>] = [:]
	
	init(favoritesStore: FavoritesStore) {
		self.favoritesStore = favoritesStore
		super.init(nibName: nil, bundle: nil)
	}
	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	deinit {
		if let observer = favoritesObserver {
			NotificationCenter.default.removeObserver(observer)
		}
		cancelAllImageTasks()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		title = Constants.favoritesTitle
		view.backgroundColor = .systemBackground
		
		tableView.translatesAutoresizingMaskIntoConstraints = false
		tableView.dataSource = self
		tableView.delegate = self
		tableView.prefetchDataSource = self
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FavoriteCell")
		view.addSubview(tableView)
		
		NSLayoutConstraint.activate([
			tableView.topAnchor.constraint(equalTo: view.topAnchor),
			tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
		
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
				if let item = note.userInfo?[FavoritesNotification.itemKey] as? FavoriteItem {
					self.items.insert(item, at: 0)
					self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
				} else {
					self.reloadFavorites()
				}
			} else {
				if let idx = self.items.firstIndex(where: { $0.id == id }) {
					self.items.remove(at: idx)
					self.tableView.deleteRows(at: [IndexPath(row: idx, section: 0)], with: .automatic)
				}
			}
		}
		
		reloadFavorites()
	}
	
	private func markRecentlyChanged(_ id: String) {
		weak var weakSelf = self
		_ = Task.detached {
			try? await Task.sleep(
				nanoseconds: UInt64(Constants.recentlyChangedWindow * 1_000_000_000)
			)
			await MainActor.run {
				guard let self = weakSelf else { return }
				self.recentlyChangedFavoriteIDs.remove(id)
			}
		}
	}
	
	private func cancelAllImageTasks() {
		imageTasks.values.forEach { $0.cancel() }
		imageTasks.removeAll()
	}
	
	private func reloadFavorites() {
		_ = Task { [weak self] in
			guard let self else { return }
			if let fetched = try? await favoritesStore.fetchAll() {
				await MainActor.run {
					self.cancelAllImageTasks()
					self.items = fetched
					self.tableView.reloadData()
				}
			}
		}
	}
	
	private func configureImageProperties(_ cfg: inout UIListContentConfiguration) {
		cfg.imageProperties.maximumSize = Constants.iconSizeCGSize
		cfg.imageProperties.reservedLayoutSize = Constants.iconSizeCGSize
		cfg.imageProperties.cornerRadius = Constants.iconCornerRadius
	}
}

extension FavoritesListViewController: UITableViewDataSource {
	func tableView(
		_ tableView: UITableView,
		numberOfRowsInSection section: Int
	) -> Int {
		items.count
	}
	
	func tableView(
		_ tableView: UITableView,
		cellForRowAt indexPath: IndexPath
	) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "FavoriteCell", for: indexPath)
		
		guard indexPath.row < items.count else { return cell }
		let item = items[indexPath.row]
		
		var content = cell.defaultContentConfiguration()
		content.text = item.title
		content.secondaryText = item.subtitle
		content.secondaryTextProperties.color = .secondaryLabel
		configureImageProperties(&content)
		content.imageProperties.tintColor = .tertiaryLabel
		
		imageTasks[indexPath]?.cancel()
		imageTasks[indexPath] = nil
		
		content.image = UIImage(systemName: Constants.placeholderIcon)
		
		if let url = item.thumbnailURL {
			if let cached = imageLoader.cachedImage(for: url) {
				content.image = cached
			} else {
				let expectedId = item.id
				let task = Task { [weak self, weak tableView] in
					guard let self else { return }
					if let image = try? await self.imageLoader.image(from: url) {
						await MainActor.run {
							guard
								let tableView,
								let visibleCell = tableView.cellForRow(at: indexPath)
							else { return }
							guard indexPath.row < self.items.count,
								  self.items[indexPath.row].id == expectedId
							else { return }
							
							if var cfg = visibleCell.contentConfiguration as? UIListContentConfiguration {
								self.configureImageProperties(&cfg)
								cfg.image = image
								visibleCell.contentConfiguration = cfg
							}
						}
					}
				}
				imageTasks[indexPath] = task
			}
		}
		
		cell.contentConfiguration = content
		cell.accessoryType = .disclosureIndicator
		return cell
	}
}

extension FavoritesListViewController: UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard indexPath.row < items.count else { return }
		let item = items[indexPath.row]
		onSelect?(item.id, item.title, item.thumbnailURL)
	}
	
	func tableView(
		_ tableView: UITableView,
		trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
	) -> UISwipeActionsConfiguration? {
		let delete = UIContextualAction(style: .destructive, title: Constants.deleteTitle) { [weak self] _, _, completion in
			guard let self else { completion(false); return }
			guard indexPath.row < self.items.count else { completion(false); return }
			
			let id = self.items[indexPath.row].id
			
			self.markRecentlyChanged(id)
			
			_ = Task { [weak self] in
				guard let self else { return }
				do {
					try await self.favoritesStore.remove(id: id)
					await MainActor.run {
						if let idx = self.items.firstIndex(where: { $0.id == id }) {
							self.items.remove(at: idx)
							tableView.deleteRows(at: [IndexPath(row: idx, section: 0)], with: .automatic)
						}
						completion(true)
					}
				} catch {
					await MainActor.run { completion(false) }
				}
			}
		}
		return UISwipeActionsConfiguration(actions: [delete])
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

extension FavoritesListViewController: UITableViewDataSourcePrefetching {
	func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
		let urls = indexPaths.compactMap { indexPath -> URL? in
			guard indexPath.row < items.count else { return nil }
			return items[indexPath.row].thumbnailURL
		}
		guard !urls.isEmpty else { return }
		_ = Task { await imageLoader.prefetch(urls: urls) }
	}
	
	func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
		_ = Task {
			for indexPath in indexPaths {
				guard indexPath.row < items.count,
					  let url = items[indexPath.row].thumbnailURL else { continue }
				await imageLoader.cancelPrefetch(url: url)
			}
		}
	}
}
