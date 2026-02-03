# HomeCookBook  
Кулинарная книга

Финальный проект iOS стажировки ШИФТ (ЦФТ)  

iOS-приложение на UIKit

Загружает рецепты из открытого API [TheMealDB](https://www.themealdb.com)  
Показывает список блюд, детали рецепта, реализован поиск и хранение в избранном

---

<img width="400" height="2622" alt="home" src="https://github.com/user-attachments/assets/fa8bec89-efa1-4aa4-9aaa-4d23c56c26d6" />
<img width="400" height="2622" alt="dark" src="https://github.com/user-attachments/assets/2fd55a35-57d6-492c-80d3-5265b0946be7" />
<img width="400" height="2622" alt="detail" src="https://github.com/user-attachments/assets/8563ec9f-dccc-468a-87fe-23ec889e51f5" />
<img width="400" height="2622" alt="search" src="https://github.com/user-attachments/assets/0ba217f5-3322-46e7-8621-f417c22a43fd" />
<img width="400" height="2622" alt="filters" src="https://github.com/user-attachments/assets/0fcc4c6e-a894-48d0-8b79-2f04ebb4a35d" />
<img width="400" height="2622" alt="delete" src="https://github.com/user-attachments/assets/230be7c8-c25e-49cd-a1e3-4eb694072233" />

---

## Функционал
- Загрузка рецептов из API, список и экран деталей  
- рандомная загрузка первой страницы (условная, ограничение API)    
- Поиск по рецептам/категориям  
- Фильтр по категориям    
- Избранное с сохранением между запусками (Core Data)    
- Кэш изображений (memory + disk) + предзагузка   
- Поддержка светлой/тёмной темы  
  
---

## Стек  
- UIKit
- VIPER + Assembly
- Swift Concurrency (async/await, actor)  
- Core Data   
- Сетевой слой: `URLSession` + `JSONDecoder`      
- Кэш изображений: `NSCache` + диск `FileManager`     

---

## Планируемые улучшения:

- вынести экран избранного в полноценный VIPER-модуль
- расширить фильтры:
  - по стране
  - по ингредиентам
  - по типу блюда
- добавить локализацию интерфейса **RU**
- подключить рецепты коктейлей по API [TheCocktailDB](https://www.thecocktaildb.com)
- добавить раздела «Случайный рецепт».

---

Запуск:
  1. Клонировать репозиторий.
  2. Запустить в Xcode на симуляторе или устройстве с **iOS 15.6+**
     
