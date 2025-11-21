//
//  FavoritesListViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 21.11.2025.
//

import UIKit

final class FavoritesListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
	
	private let favoritesStore: FavoritesStore
	var onSelect: ((String) -> Void)?
	
	private var items: [FavoriteItem] = []
	private let tableView = UITableView(frame: .zero, style: .insetGrouped)
	private var favoritesObserver: NSObjectProtocol?
	
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
		) { [weak self] _ in
			self?.reloadFavorites()
		}
		
		reloadFavorites()
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
		onSelect?(item.id)
	}
}

