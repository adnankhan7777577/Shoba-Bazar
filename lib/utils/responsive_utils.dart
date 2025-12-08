import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  
  // Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  // Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  // Check if mobile
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }
  
  // Check if tablet
  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }
  
  // Check if desktop
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= tabletBreakpoint;
  }
  
  // Get responsive cross axis count for product grids
  static int getProductGridCrossAxisCount(BuildContext context) {
    if (isMobile(context)) {
      return 2;
    } else if (isTablet(context)) {
      return 3;
    } else {
      return 4;
    }
  }
  
  // Get responsive cross axis count for category/brand grids
  static int getCategoryGridCrossAxisCount(BuildContext context) {
    if (isMobile(context)) {
      return 3;
    } else if (isTablet(context)) {
      return 4;
    } else {
      return 5;
    }
  }
  
  // Get responsive cross axis count for small grids (like image selection)
  static int getSmallGridCrossAxisCount(BuildContext context) {
    if (isMobile(context)) {
      return 2;
    } else if (isTablet(context)) {
      return 3;
    } else {
      return 4;
    }
  }
  
  // Get responsive padding
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32.0);
    }
  }
  
  // Get responsive horizontal padding
  static double getHorizontalPadding(BuildContext context) {
    if (isMobile(context)) {
      return 16.0;
    } else if (isTablet(context)) {
      return 24.0;
    } else {
      return 32.0;
    }
  }
  
  // Get responsive spacing
  static double getSpacing(BuildContext context) {
    if (isMobile(context)) {
      return 12.0;
    } else if (isTablet(context)) {
      return 16.0;
    } else {
      return 20.0;
    }
  }
  
  // Get responsive grid spacing
  static double getGridSpacing(BuildContext context) {
    if (isMobile(context)) {
      return 12.0;
    } else if (isTablet(context)) {
      return 16.0;
    } else {
      return 20.0;
    }
  }
  
  // Get responsive child aspect ratio for product cards
  static double getProductCardAspectRatio(BuildContext context) {
    if (isMobile(context)) {
      return 0.75;
    } else if (isTablet(context)) {
      return 0.7;
    } else {
      return 0.65;
    }
  }
  
  // Get responsive child aspect ratio for category cards
  static double getCategoryCardAspectRatio(BuildContext context) {
    return 1.0; // Keep square for categories
  }
  
  // Get responsive font size multiplier
  static double getFontSizeMultiplier(BuildContext context) {
    if (isMobile(context)) {
      return 1.0;
    } else if (isTablet(context)) {
      return 1.1;
    } else {
      return 1.2;
    }
  }
  
  // Get responsive banner height
  static double getBannerHeight(BuildContext context) {
    if (isMobile(context)) {
      return 180.0;
    } else if (isTablet(context)) {
      return 220.0;
    } else {
      return 250.0;
    }
  }
  
  // Get responsive product card image height
  static double getProductCardImageHeight(BuildContext context) {
    if (isMobile(context)) {
      return 120.0;
    } else if (isTablet(context)) {
      return 140.0;
    } else {
      return 160.0;
    }
  }
}

