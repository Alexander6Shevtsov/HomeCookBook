//
//  FavoritesListViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 21.11.2025.
//

import UIKit

final class FavoritesListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
	
	private let favoritesStore: FavoritesStore
	var onSelect: ((String, String?, URL?) -> Void)?
	
	private var items: [FavoriteItem] = []
	private let tableView = UITableView(frame: .zero, style: .insetGrouped)
	private var favoritesObserver: NSObjectProtocol?
	private var recentlyChangedFavoriteIDs: Set<String> = []
	
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
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Favorites"
		view.backgroundColor = .systemBackground
		
		tableView.translatesAutoresizingMaskIntoConstraints = false
		tableView.dataSource = self
		tableView.delegate = self
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
		recentlyChangedFavoriteIDs.insert(id)
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
			self?.recentlyChangedFavoriteIDs.remove(id)
		}
	}
	
	private func reloadFavorites() {
		Task { [weak self] in
			guard let self else { return }
			do {
				let fetched = try await favoritesStore.fetchAll()
				await MainActor.run {
					self.items = fetched
					self.tableView.reloadData()
				}
			} catch {
			}
		}
	}
	
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
		let reuseId = "FavoriteCell"
		let cell = tableView.dequeueReusableCell(
			withIdentifier: reuseId
		) ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseId)
		let item = items[indexPath.row]
		cell.textLabel?.text = item.title
		cell.detailTextLabel?.text = item.subtitle
		cell.accessoryType = .disclosureIndicator
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let item = items[indexPath.row]
		onSelect?(item.id, item.title, item.thumbnailURL)
	}
	
	func tableView(
		_ tableView: UITableView,
		trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
	) -> UISwipeActionsConfiguration? {
		let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
			guard let self else { completion(false); return }
			guard indexPath.row < self.items.count else { completion(false); return }
			
			let id = self.items[indexPath.row].id
			
			self.markRecentlyChanged(id)
			
			Task { [weak self] in
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
}

