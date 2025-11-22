//
//  StateOverlayView.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 21.11.2025.
//

import UIKit

final class StateOverlayView: UIView {
	var onRetry: (() -> Void)?
	
	private let stack = UIStackView()
	private let symbolView = UIImageView()
	private let titleLabel = UILabel()
	private let messageLabel = UILabel()
	private let retryButton = UIButton(type: .system)
	
	private enum UIConst {
		static let stackSpacing: CGFloat = 12
		static let stackHorizontalInset: CGFloat = 24
		static let symbolSize: CGFloat = 48
		static let symbolPointSize: CGFloat = 44
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}
	
	private func setup() {
		backgroundColor = .systemBackground
		
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .vertical
		stack.alignment = .center
		stack.spacing = UIConst.stackSpacing
		
		symbolView.translatesAutoresizingMaskIntoConstraints = false
		symbolView.tintColor = .tertiaryLabel
		symbolView.contentMode = .scaleAspectFit
		
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
		titleLabel.adjustsFontForContentSizeCategory = true
		titleLabel.textColor = .label
		titleLabel.numberOfLines = 0
		titleLabel.textAlignment = .center
		
		messageLabel.translatesAutoresizingMaskIntoConstraints = false
		messageLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
		messageLabel.adjustsFontForContentSizeCategory = true
		messageLabel.textColor = .secondaryLabel
		messageLabel.numberOfLines = 0
		messageLabel.textAlignment = .center
		
		retryButton.translatesAutoresizingMaskIntoConstraints = false
		retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
		
		addSubview(stack)
		stack.addArrangedSubview(symbolView)
		stack.addArrangedSubview(titleLabel)
		stack.addArrangedSubview(messageLabel)
		stack.addArrangedSubview(retryButton)
		
		NSLayoutConstraint.activate(
			[
				stack.centerXAnchor.constraint(equalTo: centerXAnchor),
				stack.centerYAnchor.constraint(equalTo: centerYAnchor),
				stack.leadingAnchor.constraint(
					greaterThanOrEqualTo: leadingAnchor,
					constant: UIConst.stackHorizontalInset
				),
				stack.trailingAnchor.constraint(
					lessThanOrEqualTo: trailingAnchor,
					constant: -UIConst.stackHorizontalInset
				),
				
				symbolView.widthAnchor.constraint(equalToConstant: UIConst.symbolSize),
				symbolView.heightAnchor.constraint(equalToConstant: UIConst.symbolSize)
			]
		)
	}
	
	func configure(
		symbolName: String,
		title: String,
		message: String,
		buttonTitle: String?
	) {
		let config = UIImage.SymbolConfiguration(
			pointSize: UIConst.symbolPointSize,
			weight: .regular
		)
		symbolView.image = UIImage(systemName: symbolName, withConfiguration: config)
		
		titleLabel.text = title
		messageLabel.text = message
		
		if let title = buttonTitle, !title.isEmpty {
			retryButton.isHidden = false
			retryButton.setTitle(title, for: .normal)
		} else {
			retryButton.isHidden = true
			retryButton.setTitle(nil, for: .normal)
		}
	}
	
	@objc private func didTapRetry() {
		onRetry?()
	}
}
