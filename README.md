# HomeCookBook
## Домашняя кулинарная книга

Финальный проект iOS-стажировки ШИФТ (ЦФТ)  

iOS-приложение на UIKit

Загружает рецепты из открытого API [TheMealDB](https://www.themealdb.com)  
Показывает список блюд, детали рецепта, позволяет искать и сохранять в избранное

---

<img width="400" height="2622" alt="home" src="https://github.com/user-attachments/assets/fa8bec89-efa1-4aa4-9aaa-4d23c56c26d6" />
<img width="400" height="2622" alt="dark" src="https://github.com/user-attachments/assets/2fd55a35-57d6-492c-80d3-5265b0946be7" />
<img width="400" height="2622" alt="detail" src="https://github.com/user-attachments/assets/8563ec9f-dccc-468a-87fe-23ec889e51f5" />
<img width="400" height="2622" alt="search" src="https://github.com/user-attachments/assets/0ba217f5-3322-46e7-8621-f417c22a43fd" />
<img width="400" height="2622" alt="filters" src="https://github.com/user-attachments/assets/0fcc4c6e-a894-48d0-8b79-2f04ebb4a35d" />
<img width="400" height="2622" alt="delete" src="https://github.com/user-attachments/assets/230be7c8-c25e-49cd-a1e3-4eb694072233" />

---

## Основные функции

- Главный экран:
  - коллекция карточек с обложкой и названием блюда
  - рандомная загрузка первой страницы (условная, ограничение API) 
  - поиск по названию (если нет результатов — по категориям)
  - фильтр по категориям (меню категорий)
  - добавление и удаление из списка избранного  

- Избранное:
  - список сохранённых рецептов
  - удаление свайпом
  - переход к экрану деталей
  - последние добавленные сверху

- Кэширование:
  - избранные рецепты хранятся в Core Data и доступны между запусками
  - изображения кэшируются в `NSCache` и на диске через `FileManager`
  - предзагрузка изображений

- Поддержка светлой/темной темы
  
---

## Стек проекта
- Swift 5+, iOS 15.6+
- UIKit: `UICollectionView`, `UITableView`, `UISearchController`, `UINavigationController`
- Архитектура:
  - VIPER для модулей `RecipeList` и `RecipeDetail`
  - отдельный экран `FavoritesList`
- Сетевой слой: `URLSession` + `JSONDecoder` (API TheMealDB)
- Хранение:
  - Core Data для избранных рецептов
  - файловый кэш изображений `NSCache` + `FileManager`
- Concurrency:
  - Swift Concurrency (`async/await`, `actor`, `Task`, `MainActor`)
- Инфраструктура:
  - `NotificationCenter` (синхронизация избранного между экранами)

---

## Архитектура

### Data
Работа с сетью и локальным хранилищем:
- `Persistence` — Core Data-стек и модель `FavoriteRecipeMO`
- `Favorites` — слой управления избранными (`FavoritesStore`)
- `Networking` — протокол `NetworkClient` и реализация на `URLSession`
- `DTO` — модели API TheMealDB (`MealSearchDTO`, `MealLookupDTO`)
- `Services` — сервис `TheMealDBService` для работы с API и маппинга DTO

### Domain
Доменная модель:
- RecipeListItemEntity — краткое описание блюда для списка
- RecipeDetailEntity — детали рецепта (заголовок, изображение, текст)

### Presentation (VIPER)
Каждый экран — отдельный модуль:

- **RecipeList**
  - список рецептов, поиск, фильтрация, пагинация
- **RecipeDetail**
  - отображение деталей рецепта
- **Favorites**
  - экран со списком избранных рецептов

Структура VIPER-модулей:

- `Contracts` — протоколы View / Presenter / Interactor / Router
- `Models` — ViewModel’и для отображения
- `View` — контроллеры и вью-классы
- `Presenter` — связывает View и Interactor
- `Interactor` — бизнес-логика и работа с сервисами
- `Router` — навигация между экранами
- `Assembly` — сборка модулей и внедрение зависимостей

### Utilities
- `ImageLoader` — загрузка и кэширования и предзагрузка изображений

---

## Работа с сетью и данными

- API: [https://www.themealdb.com/api.php](https://www.themealdb.com/api.php)
- Сетевой слой:
  - `NetworkClient` — абстракция над сетевыми запросами
  - `URLSessionNetworkClient` — реализация на базе `URLSession` с `async/await`
- `TheMealDBService`:
  - загрузка списка блюд по букве (`search.php?f=`)
  - поиск по названию (`search.php?s=`)
  - фильтрация по категориям (`filter.php?c=`)
  - получение деталей рецепта (`lookup.php?i=`)
- Core Data:
  - `CoreDataStack` — создание `NSPersistentContainer`
  - `FavoritesStore` — добавление, удаление и выборка избранных рецептов
- Изображения:
  - `ImageLoader` генерирует FNV-hash по URL, кэширует изображение в памяти (`NSCache`) и на диске (`FileManager`)
  - используется prefetching коллекции для фоновой загрузки картинок при скролле

---

## Планируемые улучшения:

- вынести экран избранного в полноценный VIPER-модуль
- расширить фильтры:
  - по стране
  - по ингредиентам
  - по типу блюда
- добавить локализацию интерфейса **RU / EN**
- подключить рецепты коктейлей по API [TheCocktailDB](https://www.thecocktaildb.com)
- добавить раздела «Случайный рецепт».

---

Запуск:
  1. Клонировать репозиторий.
  2. Запустить в Xcode на симуляторе или устройстве с **iOS 15.6+**
     
---

## Структура проекта 

```text
App/
  AppDelegate.swift
  SceneDelegate.swift

Data/
  Persistence/
    CoreDataStack.swift
  Favorites/
    FavoritesStore.swift
    FavoriteRecipeMO.swift
  Networking/
    NetworkClient.swift
  DTO/
    MealSearchDTO.swift
    MealLookupDTO.swift
  Services/
    MealsService.swift

Domain/
  Entities/
    RecipeListItemEntity.swift

Presentation/
  Modules/
    RecipeList/
      Contracts/
        RecipeListContracts.swift
      Models/
        RecipeListModels.swift
      View/
        Cell/
          RecipeCardCell.swift
        Collection/
          RecipeListCollectionController.swift
        Filter/
          RecipeListFilterMenuBuilder.swift
        Layout/
          RecipeListLayoutCalculator.swift
        Favorites/
          RecipeListFavoritesObserver.swift
        RecipeListViewController.swift
        StateOverlayView.swift
      Presenter/
        RecipeListPresenter.swift
      Interactor/
        RecipeListInteractor.swift
      Router/
        RecipeListRouter.swift
      Assembly/
        RecipeListAssembly.swift

    RecipeDetail/
      Contracts/
        RecipeDetailContracts.swift
      View/
        RecipeDetailViewController.swift
      Presenter/
        RecipeDetailPresenter.swift
      Interactor/
        RecipeDetailInteractor.swift
      Router/
        RecipeDetailRouter.swift
      Assembly/
        RecipeDetailAssembly.swift

    FavoritesList/
      View/
        FavoritesListViewController.swift

Utilities/
  ImageLoader.swift

Resources/
  LaunchScreen
  Assets.xcassets
