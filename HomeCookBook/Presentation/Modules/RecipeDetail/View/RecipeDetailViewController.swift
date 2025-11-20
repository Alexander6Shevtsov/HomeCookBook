//
//  RecipeDetailViewController.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 20.11.2025.
//

import UIKit

final class RecipeDetailViewController: UIViewController {
	
	var output: RecipeDetailViewOutput?
	
	private let imageView = UIImageView()
	private let textView = UITextView()
	
	private enum Constants {
		static let title = "Recipe"
		static let spacing: CGFloat = 12
		static let imageHeight: CGFloat = 220
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		output?.viewDidLoad()
	}
	
	private func setupUI() {
		view.backgroundColor = .systemBackground
		title = Constants.title
		
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = .secondarySystemBackground
		
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
	}
}

extension RecipeDetailViewController: RecipeDetailViewInput {
	func display(title: String, imageURL: URL?, instructions: String) {
		self.title = title
		textView.text = instructions
		
		if imageURL != nil {
			imageView.image = UIImage(systemName: "photo")
			imageView.tintColor = .tertiaryLabel
		} else {
			imageView.image = UIImage(systemName: "photo")
			imageView.tintColor = .tertiaryLabel
		}
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
