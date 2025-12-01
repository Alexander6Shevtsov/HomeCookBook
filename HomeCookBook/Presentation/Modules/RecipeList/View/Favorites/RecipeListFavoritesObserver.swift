//
//  RecipeListFavoritesObserver.swift
//  HomeCookBook
//
//  Created by Alexander Shevtsov on 01.12.2025.
//

import Foundation

final class RecipeListFavoritesObserver {
	private let favoritesStore: FavoritesStoreProtocol
	private let debounceWindow: TimeInterval
	private var favoriteIDs: Set<String> = []
	private var recentlyChanged: Set<String> = []
	private var observer: NSObjectProtocol?
	
	var onInitialFavoritesLoaded: ((Set<String>) -> Void)?
	var onFavoriteChanged: ((String, Bool) -> Void)?
	
	init(
		favoritesStore: FavoritesStoreProtocol,
		debounceWindow: TimeInterval = 1.0
	) {
		self.favoritesStore = favoritesStore
		self.debounceWindow = debounceWindow
	}
	
	deinit {
		stop()
	}
	
	func start() {
		Task { [weak self] in
			guard let self else { return }
			if let items = try? await favoritesStore.fetchAll() {
				let idSet = Set(items.map(\.id))
				await MainActor.run { [weak self] in
					self?.favoriteIDs = idSet
					self?.onInitialFavoritesLoaded?(idSet)
				}
			}
		}
		
		observer = NotificationCenter.default.addObserver(
			forName: .favoritesDidChange,
			object: nil,
			queue: .main
		) { [weak self] notification in
			guard
				let self,
				let id = notification.userInfo?[FavoritesNotification.idKey] as? String,
				let isFavorite = notification.userInfo?[FavoritesNotification.isFavoriteKey] as? Bool
			else {
				return
			}
			
			if self.recentlyChanged.contains(id) {
				return
			}
			
			if isFavorite {
				self.favoriteIDs.insert(id)
			} else {
				self.favoriteIDs.remove(id)
			}
			self.onFavoriteChanged?(id, isFavorite)
		}
	}
	
	func stop() {
		if let observer {
			NotificationCenter.default.removeObserver(observer)
		}
		observer = nil
	}
	
	func markRecentlyChanged(id: String) {
		Task { [weak self] in
			_ = await MainActor.run { [weak self] in
				self?.recentlyChanged.insert(id)
			}
			guard let self else { return }
			try? await Task.sleep(nanoseconds: UInt64(self.debounceWindow * 1_000_000_000))
			_ = await MainActor.run { [weak self] in
				self?.recentlyChanged.remove(id)
			}
		}
	}
}
