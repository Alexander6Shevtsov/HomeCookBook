//
//  RecipeCardCell.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeCardCell: UICollectionViewCell {
	static let reuseId = "RecipeCardCell"
	
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
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupUI()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupUI()
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		imageView.layer.removeAllAnimations()
		titleLabel.text = nil
		subtitleLabel.text = nil
		onToggleFavorite = nil
		isFavorite = false
		updateFavoriteAppearance()
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
		titleLabel.numberOfLines = 2
		
		subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
		subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
		subtitleLabel.adjustsFontForContentSizeCategory = true
		subtitleLabel.textColor = .secondaryLabel
		subtitleLabel.numberOfLines = 1
		
		labelsStack.translatesAutoresizingMaskIntoConstraints = false
		labelsStack.axis = .vertical
		labelsStack.alignment = .fill
		labelsStack.distribution = .fill
		labelsStack.spacing = UIConst.labelsSpacing
		labelsStack.addArrangedSubview(titleLabel)
		labelsStack.addArrangedSubview(subtitleLabel)
		
		favoriteButton.translatesAutoresizingMaskIntoConstraints = false
		let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
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
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		updateShadow()
	}
	
	private func updateShadow() {
		guard let bgLayer = backgroundView?.layer else { return }
		bgLayer.shadowColor = UIColor.label.withAlphaComponent(0.15).cgColor
		bgLayer.shadowOpacity = 1.0
		bgLayer.shadowOffset = CGSize(width: 0, height: 4)
		bgLayer.shadowRadius = 10
		bgLayer.cornerRadius = UIConst.cornerRadius
		bgLayer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: UIConst.cornerRadius).cgPath
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
		imageView.image = UIImage(systemName: "photo")
		imageView.tintColor = .tertiaryLabel
	}
	
	func setImage(_ image: UIImage) {
		UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve, animations: {
			self.imageView.image = image
			self.imageView.tintColor = nil
		}, completion: nil)
	}
	
	private func updateFavoriteAppearance() {
		let imageName = isFavorite ? "star.fill" : "star"
		let image = UIImage(systemName: imageName)
		favoriteButton.setImage(image, for: .normal)
		favoriteButton.alpha = isFavorite ? 1.0 : 0.9
	}
	
	@objc private func didTapFavorite() {
		onToggleFavorite?()
	}
}

