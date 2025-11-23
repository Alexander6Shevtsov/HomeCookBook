# HomeCookBook
## Домашняя кулинарная книга

iOS-приложение на UIKit

Загружает рецепты из открытого API [TheMealDB](https://www.themealdb.com), показывает список блюд, детали рецепта и позволяет искать и сохранять в избранное

Минимальная версия iOS: **15+**

Архитектура: VIPER

---

## Основные функции

- Список рецептов:
  - коллекция карточек с обложкой и названием блюда
  - поиск по названию (если нет результатов — по категориям)
  - фильтр по категориям
  - добавление и удаление из избранного  

- Избранное:
  - список сохранённых рецептов
  - удаление свайпом
  - переход к экрану деталей

- Кэширование:
  - избранные рецепты сохраняются в Core Data и доступны между запусками
  - изображения кэшируются в оперативной памяти и на диске.

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
- `RecipeListItemEntity` — описание блюда, используемое в бизнес-логике

### Presentation (VIPER)
Каждый экран оформлен отдельным модулем:

- **RecipeList**
  - список рецептов, поиск, фильтрация, пагинация
- **RecipeDetail**
  - отображение деталей рецепта
- **Favorites**
  - экран со списком избранных рецептов

Структура VIPER-модулей:

- `Contracts` — View / Presenter / Interactor / Router
- `Models` — ViewModel’и для отображения
- `View` — контроллеры и вью-классы
- `Presenter` — связывает View и Interactor
- `Interactor` — бизнес-логика и работа с сервисами
- `Router` — навигация
- `Assembly` — сборка модулей и внедрение зависимостей

### Utilities
- `ImageLoader` — актор для загрузки и кэширования изображений (memory + disk cache)

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

## Направление развития

- выделенный VIPER-модуль для экрана избранного
- расширенные фильтры (страна, ингредиенты, тип блюда)
- локализация RU/EN
- добавление рецептов коктейлей (TheCocktailDB)

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
    TheMealDBService.swift

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
