import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/responsive_utils.dart';
import '../customer/screens/product_detail_screen.dart';

/// A reusable product card widget that can be used in GridView or ListView
/// 
/// Supports two layouts:
/// - GridView layout: Uses Expanded with flex ratios for image and details
/// - ListView layout: Uses fixed height for image (for horizontal scrolling)
class ProductCard extends StatelessWidget {
  final String? productImage;
  final String productName;
  final String productPrice;
  final double productRating;
  final Map<String, dynamic> productData;
  final VoidCallback? onTap;
  final bool useGridViewLayout; // true for GridView, false for ListView
  final bool showFiveStarRating; // true to show 5 stars, false for single star with number
  final double? cardWidth; // For ListView layout
  final double? imageHeight; // For ListView layout
  final bool hideActionIcons; // For ProductDetailScreen
  final EdgeInsets? margin; // For ListView layout
  final TextStyle? titleStyle;
  final TextStyle? priceStyle;
  final Color? cardColor;
  final double? horizontalPadding;
  final double? verticalPadding;

  const ProductCard({
    super.key,
    required this.productImage,
    required this.productName,
    required this.productPrice,
    required this.productRating,
    required this.productData,
    this.onTap,
    this.useGridViewLayout = true,
    this.showFiveStarRating = false,
    this.cardWidth,
    this.imageHeight,
    this.hideActionIcons = false,
    this.margin,
    this.titleStyle,
    this.priceStyle,
    this.cardColor,
    this.horizontalPadding,
    this.verticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: productData,
              hideActionIcons: hideActionIcons,
            ),
          ),
        );
      },
      child: Container(
        width: cardWidth,
        margin: margin,
        decoration: BoxDecoration(
          color: cardColor ?? (useGridViewLayout ? AppColors.white : AppColors.surface),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: useGridViewLayout ? AppColors.shadow : AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: useGridViewLayout ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Product Image
            useGridViewLayout
                ? Expanded(
                    flex: 3,
                    child: _buildImage(context),
                  )
                : _buildImage(context, fixedHeight: imageHeight ?? ResponsiveUtils.getProductCardImageHeight(context)),
            
            // Product Details
            useGridViewLayout
                ? Expanded(
                    flex: 2,
                    child: _buildDetails(context),
                  )
                : _buildDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, {double? fixedHeight}) {
    return Container(
      height: fixedHeight,
      width: fixedHeight != null ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        color: AppColors.background,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: productImage != null && productImage!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: productImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: fixedHeight ?? double.infinity,
                placeholder: (context, url) => Container(
                  width: double.infinity,
                  height: fixedHeight ?? double.infinity,
                  color: AppColors.background,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: double.infinity,
                  height: fixedHeight ?? double.infinity,
                  color: AppColors.background,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.textLight,
                  ),
                ),
              )
            : Container(
                width: double.infinity,
                height: fixedHeight ?? double.infinity,
                color: AppColors.background,
                child: const Icon(
                  Icons.image_not_supported,
                  color: AppColors.textLight,
                ),
              ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    // Use less padding for GridView to prevent overflow with 2-line titles
    final effectiveVerticalPadding = verticalPadding ?? (useGridViewLayout ? 4.0 : 6.0);
    final spacingBetween = useGridViewLayout ? 4.0 : 6.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding ?? (useGridViewLayout ? 10.0 : 10.0),
        vertical: effectiveVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product Title - allows up to 2 lines, no fixed height
          Text(
            productName,
            style: titleStyle ?? AppTextStyles.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacingBetween),
          // Price
          Text(
            productPrice,
            style: priceStyle ?? AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacingBetween),
          // Ratingiii
          _buildRating(context),
        ],
      ),
    );
  }

  Widget _buildRating(BuildContext context) {
    if (showFiveStarRating) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(5, (starIndex) {
            return Icon(
              starIndex < productRating.floor()
                  ? Icons.star
                  : Icons.star_border,
              color: AppColors.warning,
              size: 14,
            );
          }),
          if (productRating > 0) ...[
            const SizedBox(width: 4),
            Text(
              productRating.toStringAsFixed(1),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ],
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star,
            color: AppColors.warning,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            productRating.toStringAsFixed(1),
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
  }
}

