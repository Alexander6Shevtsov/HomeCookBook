//
//  RecipeListViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeListViewController: UIViewController {
	
	weak var output: RecipeListViewOutput?
	
	private let tableView = UITableView(frame: .zero, style: .plain)
	
	private var items: [RecipeListItemViewModel] = []
	
	private enum Constants {
		static let rowHeight: CGFloat = 72
		static let cellReuseId = "RecipeCell"
		static let title = "Recipes"
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
		
		view.addSubview(tableView)
		
		NSLayoutConstraint.activate([
			tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
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
		let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellReuseId, for: indexPath)
		let vm = items[indexPath.row]
		var config = cell.defaultContentConfiguration()
		config.text = vm.title
		config.secondaryText = vm.subtitle
		cell.contentConfiguration = config
		cell.accessoryType = .disclosureIndicator
		return cell
	}
}


extension RecipeListViewController: UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		output?.didSelectItem(at: indexPath.row)
		tableView.deselectRow(at: indexPath, animated: true)
	}
}


extension RecipeListViewController: RecipeListViewInput {
	func display(items: [RecipeListItemViewModel]) {
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
	
	func showError(message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
