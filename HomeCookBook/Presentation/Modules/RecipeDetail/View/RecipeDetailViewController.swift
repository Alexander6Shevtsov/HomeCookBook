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
	var initialTitle: String?
	var initialImageURL: URL?
	var initialImage: UIImage?
	
	private let scrollView = UIScrollView()
	private let contentStack = UIStackView()
	
	private let titleLabel = UILabel()
	private let imageView = UIImageView()
	private let instructionsLabel = UILabel()
	
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
	private var recentlyChangedFavoriteIDs: Set<String> = []
	
	private var currentTitleText: String?
	
	private enum Constants {
		static let fallbackTitle = "Recipe"
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
		
		navigationItem.largeTitleDisplayMode = .never
		navigationItem.title = nil
		
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.alwaysBounceVertical = true
		
		contentStack.translatesAutoresizingMaskIntoConstraints = false
		contentStack.axis = .vertical
		contentStack.alignment = .fill
		contentStack.distribution = .fill
		contentStack.spacing = Constants.spacing
		contentStack.isLayoutMarginsRelativeArrangement = true
		contentStack.layoutMargins = UIEdgeInsets(
			top: Constants.spacing,
			left: Constants.spacing,
			bottom: Constants.spacing,
			right: Constants.spacing
		)
		
		titleLabel.numberOfLines = 0
		titleLabel.textColor = .label
		titleLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
		titleLabel.adjustsFontForContentSizeCategory = true
		titleLabel.text = initialTitle ?? Constants.fallbackTitle
		currentTitleText = titleLabel.text
		
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = .secondarySystemBackground
		imageView.image = UIImage(systemName: "photo")
		imageView.tintColor = .tertiaryLabel
		imageView.heightAnchor.constraint(equalToConstant: Constants.imageHeight).isActive = true
		
		if let initialImage {
			imageView.image = initialImage
			imageView.tintColor = nil
		}
		else if let url = initialImageURL, let cached = imageLoader.cachedImage(for: url) {
			imageView.image = cached
			imageView.tintColor = nil
		}
		
		instructionsLabel.numberOfLines = 0
		instructionsLabel.textColor = .label
		instructionsLabel.font = .preferredFont(forTextStyle: .body)
		instructionsLabel.adjustsFontForContentSizeCategory = true
		
		view.addSubview(scrollView)
		scrollView.addSubview(contentStack)
		
		contentStack.addArrangedSubview(titleLabel)
		contentStack.addArrangedSubview(imageView)
		contentStack.addArrangedSubview(instructionsLabel)
		
		NSLayoutConstraint.activate([
			scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			
			contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
			contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
			contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
			contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
			
			contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
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
		) { [weak self] note in
			guard let self else { return }
			guard
				let id = note.userInfo?[FavoritesNotification.idKey] as? String,
				let isFav = note.userInfo?[FavoritesNotification.isFavoriteKey] as? Bool
			else { return }
			guard id == self.mealId else { return }
			
			if self.recentlyChangedFavoriteIDs.contains(id) { return }
			
			self.isFavorite = isFav
			self.updateFavoriteBarButton()
		}
	}
	
	private func updateFavoriteBarButton() {
		let imageName = isFavorite ? "star.fill" : "star"
		favoriteBarButtonItem.image = UIImage(systemName: imageName)
	}
	
	private func markRecentlyChanged(_ id: String) {
		recentlyChangedFavoriteIDs.insert(id)
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
			self?.recentlyChangedFavoriteIDs.remove(id)
		}
	}
	
	@objc private func didTapFavorite() {
		let favorite = FavoriteItem(
			id: mealId,
			title: currentTitleText ?? "",
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
					self.markRecentlyChanged(self.mealId)
				}
			} catch {
			}
		}
	}
}

extension RecipeDetailViewController: RecipeDetailViewInput {
	func display(title: String, imageURL: URL?, instructions: String) {
		self.currentTitleText = title
		self.titleLabel.text = title
		self.instructionsLabel.text = instructions
		
		imageTask?.cancel()
		imageTask = nil
		
		if initialImage != nil {
			return
		}
		
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

