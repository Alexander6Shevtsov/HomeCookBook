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
	
	private var favoriteBarButtonItem: UIBarButtonItem?
	private var isFavorite: Bool = false
	private var favoritesObserver: NSObjectProtocol?
	private var recentlyChangedFavoriteIDs: Set<String> = []
	
	private var currentTitleText: String?
	private var currentImageURL: URL?
	
	private enum Constants {
		static let fallbackTitle = "Recipe"
		static let spacing: CGFloat = 12
		static let imageHeight: CGFloat = 220
		static let fadeDuration: TimeInterval = 0.25
		static let recentlyChangedWindow: TimeInterval = 1.0
		static let errorTitle = "Error"
		static let okTitle = "OK"
		static let placeholderIcon = "photo"
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
		
		setupTitleLabel()
		setupImageView()
		
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
	}
	
	private func setupTitleLabel() {
		titleLabel.numberOfLines = 0
		titleLabel.textColor = .label
		titleLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
		titleLabel.adjustsFontForContentSizeCategory = true
		titleLabel.text = initialTitle ?? Constants.fallbackTitle
		currentTitleText = titleLabel.text
	}
	
	private func setupImageView() {
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = .secondarySystemBackground
		imageView.heightAnchor.constraint(
			equalToConstant: Constants.imageHeight
		).isActive = true
		
		if let initialImage {
			imageView.image = initialImage
			imageView.tintColor = nil
		}
		else if let url = initialImageURL, let cached = imageLoader.cachedImage(for: url) {
			imageView.image = cached
			imageView.tintColor = nil
			currentImageURL = url
		} else {
			showPlaceholderImage()
		}
	}
	
	private func setupFavoriteButton() {
		favoriteBarButtonItem = UIBarButtonItem(
			image: UIImage(systemName: "star"),
			style: .plain,
			target: self,
			action: #selector(didTapFavorite)
		)
		favoriteBarButtonItem?.tintColor = .systemYellow
		navigationItem.rightBarButtonItem = favoriteBarButtonItem
		
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
		favoriteBarButtonItem?.image = UIImage(
			systemName: isFavorite ? "star.fill" : "star"
		)
	}
	
	private func markRecentlyChanged(_ id: String) {
		recentlyChangedFavoriteIDs.insert(id)
		DispatchQueue.main.asyncAfter(
			deadline: .now() + Constants.recentlyChangedWindow
		) { [weak self] in
			self?.recentlyChangedFavoriteIDs.remove(id)
		}
	}
	
	private func showPlaceholderImage() {
		imageView.image = UIImage(systemName: Constants.placeholderIcon)
		imageView.tintColor = .tertiaryLabel
	}
	
	@objc private func didTapFavorite() {
		let thumbURL = currentImageURL ?? initialImageURL
		let favorite = FavoriteItem(
			id: mealId,
			title: currentTitleText ?? "",
			subtitle: nil,
			thumbnailURL: thumbURL,
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
			} catch { }
		}
	}
}

extension RecipeDetailViewController: RecipeDetailViewInput {
	func display(title: String, imageURL: URL?, instructions: String) {
		self.currentTitleText = title
		self.titleLabel.text = title
		self.instructionsLabel.text = instructions
		self.currentImageURL = imageURL
		
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
		
		showPlaceholderImage()
		
		if let url = imageURL {
			imageTask = Task { [weak self] in
				guard let self else { return }
				if let image = try? await self.imageLoader.image(from: url) {
					await MainActor.run {
						UIView.transition(
							with: self.imageView,
							duration: Constants.fadeDuration,
							options: .transitionCrossDissolve,
							animations: {
								self.imageView.image = image
								self.imageView.tintColor = nil
							},
							completion: nil)
					}
				}
			}
		}
	}
	
	func showError(message: String) {
		let alert = UIAlertController(
			title: Constants.errorTitle,
			message: message,
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: Constants.okTitle, style: .default))
		present(alert, animated: true)
	}
}
