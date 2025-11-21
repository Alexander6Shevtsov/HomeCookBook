//
//  RecipeDetailViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeDetailViewController: UIViewController {
	
	var output: RecipeDetailViewOutput?
	
	var favoritesStore: FavoritesStore = FavoritesStoreImpl()
	var mealId: String = ""
	
	private let imageView = UIImageView()
	private let textView = UITextView()
	private let imageLoader = ImageLoader.shared
	private var imageTask: Task<Void, Never>?
	
	private lazy var activityIndicator: UIActivityIndicatorView = {
		let activity = UIActivityIndicatorView(style: .medium)
		activity.hidesWhenStopped = true
		return activity
	}()
	private lazy var activityItem = UIBarButtonItem(customView: activityIndicator)
	private var spinnerDelayTask: Task<Void, Never>?
	
	private var favoriteBarButtonItem: UIBarButtonItem!
	private var isFavorite: Bool = false
	private var favoritesObserver: NSObjectProtocol?
	
	private enum Constants {
		static let title = "Recipe"
		static let spacing: CGFloat = 12
		static let imageHeight: CGFloat = 220
	}
	
	deinit {
		if let observer = favoritesObserver {
			NotificationCenter.default.removeObserver(observer)
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupFavoriteButton()
		setupFavoritesSync()
		output?.viewDidLoad()
	}
	
	private func setupUI() {
		view.backgroundColor = .systemBackground
		title = Constants.title
		
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = .secondarySystemBackground
		imageView.image = UIImage(systemName: "photo")
		imageView.tintColor = .tertiaryLabel
		
		textView.translatesAutoresizingMaskIntoConstraints = false
		textView.isEditable = false
		textView.backgroundColor = .clear
		textView.textColor = .label
		textView.font = .preferredFont(forTextStyle: .body)
		
		view.addSubview(imageView)
		view.addSubview(textView)
		
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.spacing),
			imageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.spacing),
			imageView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.spacing),
			imageView.heightAnchor.constraint(equalToConstant: Constants.imageHeight),
			
			textView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: Constants.spacing),
			textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.spacing),
			textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.spacing),
			textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
		
		activityIndicator.stopAnimating()
	}
	
	private func setupFavoriteButton() {
		favoriteBarButtonItem = UIBarButtonItem(
			image: UIImage(systemName: "star"),
			style: .plain,
			target: self,
			action: #selector(didTapFavorite)
		)
		favoriteBarButtonItem.tintColor = .systemYellow
		navigationItem.rightBarButtonItems = [favoriteBarButtonItem, activityItem]
		
		Task { [weak self] in
			guard let self else { return }
			let isFav = await self.favoritesStore.isFavorite(id: self.mealId)
			await MainActor.run {
				self.isFavorite = isFav
				self.updateFavoriteBarButton()
			}
		}
	}
	
	private func setupFavoritesSync() {
		favoritesObserver = NotificationCenter.default.addObserver(
			forName: .favoritesDidChange,
			object: nil,
			queue: .main
		) { [weak self] _ in
			guard let self else { return }
			Task { [weak self] in
				guard let self else { return }
				let isFav = await self.favoritesStore.isFavorite(id: self.mealId)
				await MainActor.run {
					self.isFavorite = isFav
					self.updateFavoriteBarButton()
				}
			}
		}
	}
	
	private func updateFavoriteBarButton() {
		let imageName = isFavorite ? "star.fill" : "star"
		favoriteBarButtonItem.image = UIImage(systemName: imageName)
	}
	
	@objc private func didTapFavorite() {
		let favorite = FavoriteItem(
			id: mealId,
			title: title ?? "",
			subtitle: nil,
			thumbnailURL: nil,
			dateAdded: Date()
		)
		Task { [weak self] in
			guard let self else { return }
			do {
				let nowFavorite = try await self.favoritesStore.toggle(item: favorite)
				await MainActor.run {
					self.isFavorite = nowFavorite
					self.updateFavoriteBarButton()
				}
			} catch {
			}
		}
	}
}

extension RecipeDetailViewController: RecipeDetailViewInput {
	func display(title: String, imageURL: URL?, instructions: String) {
		self.title = title
		textView.text = instructions
		
		imageTask?.cancel()
		imageTask = nil
		
		if let url = imageURL, let cached = imageLoader.cachedImage(for: url) {
			imageView.image = cached
			imageView.tintColor = nil
			return
		}
		
		imageView.image = UIImage(systemName: "photo")
		imageView.tintColor = .tertiaryLabel
		
		if let url = imageURL {
			imageTask = Task { [weak self] in
				guard let self else { return }
				if let image = try? await self.imageLoader.image(from: url) {
					await MainActor.run {
						UIView.transition(with: self.imageView, duration: 0.25, options: .transitionCrossDissolve, animations: {
							self.imageView.image = image
							self.imageView.tintColor = nil
						}, completion: nil)
					}
				}
			}
		}
	}
	
	func showLoading(_ isLoading: Bool) {
		if isLoading {
			spinnerDelayTask?.cancel()
			spinnerDelayTask = Task { [weak self] in
				try? await Task.sleep(nanoseconds: 200_000_000) 
				guard let self, !Task.isCancelled else { return }
				await MainActor.run { self.activityIndicator.startAnimating() }
			}
		} else {
			spinnerDelayTask?.cancel()
			spinnerDelayTask = nil
			activityIndicator.stopAnimating()
		}
	}
	
	func showError(message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
