# Shoba Bazar - Project Structure

## Directory Structure

```
lib/
├── constants/           # App-wide constants
│   ├── app_colors.dart  # Color definitions
│   └── app_texts.dart   # Text constants
├── widgets/             # Reusable UI components
│   └── app_logo.dart    # App logo widget
├── customer/            # Customer-specific features
│   └── screens/
│       └── welcome_screen.dart
├── seller/              # Seller-specific features (future)
├── admin/               # Admin-specific features (future)
└── main.dart           # App entry point
```

## Features Implemented

### Customer Section
- ✅ Welcome Screen with app branding
- ✅ Custom logo with engine block design
- ✅ Raleway font family integration
- ✅ Primary color scheme (#80171B)
- ✅ Responsive layout design

### Design System
- ✅ Color constants (AppColors)
- ✅ Text constants (AppTexts)
- ✅ Reusable logo component
- ✅ Consistent theming

## Next Steps

1. Add Raleway font files to `fonts/` directory
2. Implement navigation between screens
3. Add seller and admin sections
4. Implement authentication flow
5. Add product catalog screens

## Font Integration

The app uses the Raleway font family via Google Fonts package. No local font files are required as fonts are automatically downloaded and cached by the Google Fonts package.

### Dependencies
- `google_fonts: ^6.2.1` - For Raleway font family integration
