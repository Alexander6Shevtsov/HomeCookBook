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
		setPlaceholder()
	}
	
	private func setupUI() {
		contentView.backgroundColor = .secondarySystemBackground
		contentView.layer.cornerRadius = 12
		contentView.layer.masksToBounds = true
		
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = .tertiarySystemBackground
		
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
		titleLabel.textColor = .label
		titleLabel.numberOfLines = 2
		
		subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
		subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
		subtitleLabel.textColor = .secondaryLabel
		subtitleLabel.numberOfLines = 1
		
		labelsStack.translatesAutoresizingMaskIntoConstraints = false
		labelsStack.axis = .vertical
		labelsStack.alignment = .fill
		labelsStack.distribution = .fill
		labelsStack.spacing = 4
		
		labelsStack.addArrangedSubview(titleLabel)
		labelsStack.addArrangedSubview(subtitleLabel)
		
		contentView.addSubview(imageView)
		contentView.addSubview(labelsStack)
		
		let padding: CGFloat = 10
		
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.75),
			
			labelsStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: padding),
			labelsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
			labelsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
			labelsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding)
		])
		
		setPlaceholder()
	}
	
	func configure(title: String, subtitle: String?) {
		titleLabel.text = title
		subtitleLabel.text = subtitle
		subtitleLabel.isHidden = (subtitle ?? "").isEmpty
	}
	
	func setPlaceholder() {
		imageView.image = UIImage(systemName: "photo")
		imageView.tintColor = .tertiaryLabel
	}
	
	func setImage(_ image: UIImage) {
		imageView.image = image
		imageView.tintColor = nil
	}
}
