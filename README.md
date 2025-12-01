# HomeCookBook
## Домашняя кулинарная книга

iOS-приложение на UIKit

Загружает рецепты из открытого API [TheMealDB](https://www.themealdb.com).  
Показывает список блюд, детали рецепта, позволяет искать и сохранять в избранное.


---

<img width="400" height="2622" alt="home" src="https://github.com/user-attachments/assets/fa8bec89-efa1-4aa4-9aaa-4d23c56c26d6" />
<img width="400" height="2622" alt="dark" src="https://github.com/user-attachments/assets/2fd55a35-57d6-492c-80d3-5265b0946be7" />
<img width="400" height="2622" alt="detail" src="https://github.com/user-attachments/assets/8563ec9f-dccc-468a-87fe-23ec889e51f5" />
<img width="400" height="2622" alt="search" src="https://github.com/user-attachments/assets/0ba217f5-3322-46e7-8621-f417c22a43fd" />
<img width="400" height="2622" alt="filters" src="https://github.com/user-attachments/assets/0fcc4c6e-a894-48d0-8b79-2f04ebb4a35d" />
<img width="400" height="2622" alt="delete" src="https://github.com/user-attachments/assets/230be7c8-c25e-49cd-a1e3-4eb694072233" />

---

## Основные функции

- Список рецептов:
  - рандомная загрузка первой страницы (условная, ограничение API) 
  - коллекция карточек с обложкой и названием блюда
  - поиск по названию (если нет результатов — по категориям)
  - фильтр по категориям (меню категорий)
  - добавление и удаление из избранного  

- Избранное:
  - список сохранённых рецептов
  - удаление свайпом
  - переход к экрану деталей
  - последние добавленные сверху

- Кэширование:
  - избранные рецепты сохраняются в Core Data и доступны между запусками
  - изображения кэшируются в NSCache и на диске
  - предзагрузка изображений

- Поддержка светлой/темной темы
  
---

## Стек проекта
- Swift 5+, iOS 15.6+
- UIKit (UICollectionView, UITableView, UISearchController, UINavigationController)
- VIPER (RecipeList, RecipeDetail) + отдельный экран Favorites
- URLSession + JSONDecoder (API TheMealDB)
- Core Data (избранное)
- ImageLoader: NSCache + FileManager
- Swift Concurrency: async/await, actor, Task
- NotificationCenter (синхронизация избранного)

---

## Архитектура

### App
Точка входа и настройка окна:
- `AppDelegate`
- `SceneDelegate`

### Data
Работа с сетью и локальными хранилищами:
- **Persistence** — Core Data стек и модель `FavoriteRecipeMO`
- **Favorites** — слой управления избранными (`FavoritesStore`)
- **Networking** — клиент `NetworkClient` и реализация на `URLSession`
- **DTO** — модели API TheMealDB (`MealSearchDTO`, `MealLookupDTO`)
- **Services** — сервис `TheMealDBService` для работы с API

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
- `Router` — навигация
- `Assembly` — сборка модулей и внедрение зависимостей

### Utilities
- `ImageLoader` — загрузка и кэширования изображений

---

## Работа с сетью и данными

- API: https://www.themealdb.com/api.php
- Сетевой слой:
  - `NetworkClient`
  - `URLSessionNetworkClient` (async/await)
- TheMealDBService:
  - загрузка списка блюд
  - фильтрация
  - получение деталей рецепта
- Core Data:
  - `CoreDataStack` для создания persistent container
  - `FavoritesStore` для управления избранными рецептами
- Изображения:
  - кэширование через `ImageLoader` (NSCache + файловый кэш)
  - предзагрузка изображений при пролистывании коллекции

---

## Планируемые улучшения:

- вынести экран избранного в полноценный VIPER-модуль
- расширить фильтры:
  - по стране
  - по ингредиентам
  - по типу блюда
- добавить локализацию интерфейса **RU / EN**
- подключить рецепты коктейлей по API [TheCocktailDB](https://www.thecocktaildb.com)
- добавить раздела «Случайные рецепты».

---

Запуск:
  1. Клонировать репозиторий.
  2. Запустить в Xcode на симулятор или устройстве с **iOS 15.6+**
     
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
        RecipeListViewController.swift
        StateOverlayView.swift
      Presentor/
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

    Favorites/
      View/
        FavoritesListViewController.swift

Utilities/
  ImageLoader.swift

Resources/
  LaunchScreen
  Assets.xcassets
