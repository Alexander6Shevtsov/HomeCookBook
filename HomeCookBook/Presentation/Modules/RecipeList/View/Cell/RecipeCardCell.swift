//
//  RecipeCardCell.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeCardCell: UICollectionViewCell {
	static let reuseIdentifier = "RecipeCardCell"
	
	private let imageView = UIImageView()
	private let titleLabel = UILabel()
	private let subtitleLabel = UILabel()
	private let labelsStack = UIStackView()
	private let shadowView = UIView()
	private let favoriteButton = UIButton(type: .system)
	
	var onToggleFavorite: (() -> Void)?
	private var isFavorite: Bool = false
	
	private enum UIConst {
		static let cornerRadius: CGFloat = 12
		static let padding: CGFloat = 10
		static let labelsSpacing: CGFloat = 4
		static let imageAspect: CGFloat = 0.75
		static let favoriteButtonSize: CGFloat = 28
		static let favoriteSymbolPointSize: CGFloat = 18
		static let titleLines = 2
		static let subtitleLines = 1
		static let imageTransitionDuration: TimeInterval = 0.2
		static let favoriteOnAlpha: CGFloat = 1.0
		static let favoriteOffAlpha: CGFloat = 0.9
		static let shadowOpacity: Float = 1.0
		static let shadowOffset = CGSize(width: 0, height: 4)
		static let shadowRadius: CGFloat = 10
		static let shadowColorAlpha: CGFloat = 0.15
	}
	
	private enum Strings {
		static let placeholderSymbol = "photo"
		static let favoriteOnSymbol = "star.fill"
		static let favoriteOffSymbol = "star"
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupUI()
	}
	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		nil
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		imageView.layer.removeAllAnimations()
		titleLabel.text = nil
		subtitleLabel.text = nil
		onToggleFavorite = nil
		isFavorite = false
		updateFavoriteAppearance()
		setPlaceholder()
	}
	
	private func setupUI() {
		shadowView.backgroundColor = .clear
		backgroundView = shadowView
		
		contentView.backgroundColor = .secondarySystemBackground
		contentView.layer.cornerRadius = UIConst.cornerRadius
		contentView.layer.masksToBounds = true
		
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = .tertiarySystemBackground
		
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
		titleLabel.adjustsFontForContentSizeCategory = true
		titleLabel.textColor = .label
		titleLabel.numberOfLines = UIConst.titleLines
		
		subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
		subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
		subtitleLabel.adjustsFontForContentSizeCategory = true
		subtitleLabel.textColor = .secondaryLabel
		subtitleLabel.numberOfLines = UIConst.subtitleLines
		
		labelsStack.translatesAutoresizingMaskIntoConstraints = false
		labelsStack.axis = .vertical
		labelsStack.alignment = .fill
		labelsStack.distribution = .fill
		labelsStack.spacing = UIConst.labelsSpacing
		labelsStack.addArrangedSubview(titleLabel)
		labelsStack.addArrangedSubview(subtitleLabel)
		
		favoriteButton.translatesAutoresizingMaskIntoConstraints = false
		let symbolConfig = UIImage.SymbolConfiguration(
			pointSize: UIConst.favoriteSymbolPointSize,
			weight: .regular
		)
		favoriteButton.setPreferredSymbolConfiguration(symbolConfig, forImageIn: .normal)
		favoriteButton.tintColor = .systemYellow
		favoriteButton.addTarget(self, action: #selector(didTapFavorite), for: .touchUpInside)
		updateFavoriteAppearance()
		
		contentView.addSubview(imageView)
		contentView.addSubview(labelsStack)
		contentView.addSubview(favoriteButton)
		
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: UIConst.imageAspect),
			
			labelsStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: UIConst.padding),
			labelsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UIConst.padding),
			labelsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UIConst.padding),
			labelsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UIConst.padding),
			
			favoriteButton.widthAnchor.constraint(equalToConstant: UIConst.favoriteButtonSize),
			favoriteButton.heightAnchor.constraint(equalToConstant: UIConst.favoriteButtonSize),
			favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UIConst.padding),
			favoriteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UIConst.padding)
		])
		
		let selectedBG = UIView()
		selectedBG.backgroundColor = .secondarySystemFill
		selectedBG.layer.cornerRadius = UIConst.cornerRadius
		selectedBG.layer.masksToBounds = true
		selectedBackgroundView = selectedBG
		
		setPlaceholder()
		updateShadow()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		backgroundView?.frame = bounds
		updateShadow()
	}
	
	override func traitCollectionDidChange(
		_ previousTraitCollection: UITraitCollection?
	) {
		super.traitCollectionDidChange(previousTraitCollection)
		updateShadow()
	}
	
	private func updateShadow() {
		guard let background = backgroundView?.layer else { return }
		background.shadowColor = UIColor.label.withAlphaComponent(
			UIConst.shadowColorAlpha
		).cgColor
		background.shadowOpacity = UIConst.shadowOpacity
		background.shadowOffset = UIConst.shadowOffset
		background.shadowRadius = UIConst.shadowRadius
		background.cornerRadius = UIConst.cornerRadius
		background.shadowPath = UIBezierPath(
			roundedRect: bounds,
			cornerRadius: UIConst.cornerRadius
		).cgPath
	}
	
	func configure(title: String, subtitle: String?, isFavorite: Bool) {
		titleLabel.text = title
		subtitleLabel.text = subtitle
		subtitleLabel.isHidden = (subtitle ?? "").isEmpty
		self.isFavorite = isFavorite
		updateFavoriteAppearance()
	}
	
	func setFavorite(_ isFavorite: Bool) {
		self.isFavorite = isFavorite
		updateFavoriteAppearance()
	}
	
	func setPlaceholder() {
		imageView.image = UIImage(systemName: Strings.placeholderSymbol)
		imageView.tintColor = .tertiaryLabel
	}
	
	func setImage(_ image: UIImage) {
		UIView.transition(
			with: imageView,
			duration: UIConst.imageTransitionDuration,
			options: .transitionCrossDissolve,
			animations: {
				self.imageView.image = image
				self.imageView.tintColor = nil
			},
			completion: nil)
	}
	
	private func updateFavoriteAppearance() {
		let imageName = isFavorite ? Strings.favoriteOnSymbol : Strings.favoriteOffSymbol
		let image = UIImage(systemName: imageName)
		favoriteButton.setImage(image, for: .normal)
		favoriteButton.alpha = isFavorite ? UIConst.favoriteOnAlpha : UIConst.favoriteOffAlpha
	}
	
	@objc private func didTapFavorite() {
		onToggleFavorite?()
	}
}
