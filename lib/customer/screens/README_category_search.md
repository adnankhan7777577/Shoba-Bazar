# Category Search Screen

## Overview
The `CategorySearchScreen` is a dynamic screen that displays products based on the selected category with category-specific filters and search functionality.

## Features

### ✅ **Dynamic Title**
- Screen title changes based on the selected category
- Supports categories like "Tire rim", "Battery", "Engine", etc.

### ✅ **Category-Specific Filters**
- **Type Filter**: Changes based on category (e.g., "18 inches" for tire rims, "12V" for batteries)
- **Model Filter**: Vehicle models relevant to the category
- **Year Filter**: Vehicle years for compatibility
- **Brand Filter**: Horizontal scrollable brand logos with selection state

### ✅ **Search Functionality**
- Dynamic search placeholder based on category
- Real-time search with debouncing (TODO: implement backend integration)

### ✅ **Product Grid**
- 2-column grid layout for products
- Product cards with images, names, prices, ratings
- Discount tags for promotional items
- Star ratings display

### ✅ **Brand Selection**
- Horizontal scrollable brand logos
- Selected brand highlighted with primary color
- "All" option to show all brands
- Uses existing `MakerLogoWidget` for consistency

## Usage

### Basic Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CategorySearchScreen(
      categoryName: 'Tire rim',
      categoryType: 'tire_rim',
    ),
  ),
);
```

### Category Types Supported
- `tire_rim`: Shows size filters (18", 19", 20", etc.)
- `battery`: Shows voltage filters (12V, 24V, 48V)
- `engine`: Shows displacement filters (1.0L, 1.2L, etc.)
- `headlight`, `seat`, `radiator`: Basic filters

### Filter Options by Category

#### Tire Rim
- **Type**: 18 inches, 19 inches, 20 inches, 21 inches, 22 inches
- **Model**: Civic 1.8, Corolla 1.6, Swift 1.2, A3 2.0, X3 2.0, C-Class 2.0
- **Year**: 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018

#### Battery
- **Type**: 12V, 24V, 48V
- **Model**: Civic, Corolla, Swift, A3, X3, C-Class
- **Year**: 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018

#### Engine
- **Type**: 1.0L, 1.2L, 1.5L, 1.8L, 2.0L, 2.4L
- **Model**: Civic Engine, Corolla Engine, Swift Engine, A3 Engine, X3 Engine, C-Class Engine
- **Year**: 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018

## Integration with Dashboard

The screen is integrated with the customer dashboard through the categories section. When a user taps on a category:

1. **"All" category**: Navigates to general search screen
2. **Specific categories**: Navigates to `CategorySearchScreen` with appropriate category name and type

## Customization

### Adding New Categories
1. Add category type to the switch statements in:
   - `_getTypeOptions()`
   - `_getModelOptions()`
   - `_getSearchPlaceholder()`

2. Update the dashboard categories list with the new type

### Modifying Filter Options
Update the respective methods to return different options based on your business requirements.

## TODO: Backend Integration
- Implement actual search API calls
- Add loading states
- Implement filter API calls
- Add error handling
- Implement product details navigation

## Dependencies
- `custom_dropdown.dart`: For filter dropdowns
- `maker_logo_widget.dart`: For brand logos
- `app_colors.dart`: For consistent styling
- `app_text_styles.dart`: For consistent typography
