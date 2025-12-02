import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';

class MakerLogoWidget extends StatelessWidget {
  final String makerName;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const MakerLogoWidget({
    super.key,
    required this.makerName,
    this.size = 40,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.lightGrey,
          width: 1,
        ),
      ),
      child: Center(
        child: _buildLogoImage(),
      ),
    );
  }

  Widget _buildLogoImage() {
    // Using car-logos-dataset from GitHub for reliable brand logos
    final logoUrl = _getMakerLogoUrl(makerName);
    
    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: size * 0.8,
      height: size * 0.8,
      fit: BoxFit.contain,
      placeholder: (context, url) => SizedBox(
        width: size * 0.8,
        height: size * 0.8,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              iconColor ?? AppColors.primary,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => _buildFallbackIcon(),
    );
  }

  Widget _buildFallbackIcon() {
    final color = iconColor ?? AppColors.primary;
    
    // Show first letter of brand name as fallback
    return Text(
      makerName.isNotEmpty ? makerName[0].toUpperCase() : '?',
      style: TextStyle(
        color: color,
        fontSize: size * 0.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _getMakerLogoUrl(String makerName) {
    // Using car-logos-dataset from GitHub
    const baseUrl = 'https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/optimized';
    
    switch (makerName.toLowerCase()) {
      case 'toyota':
        return '$baseUrl/toyota.png';
      case 'honda':
        return '$baseUrl/honda.png';
      case 'suzuki':
        return '$baseUrl/suzuki.png';
      case 'audi':
        return '$baseUrl/audi.png';
      case 'bmw':
        return '$baseUrl/bmw.png';
      case 'mercedes':
      case 'mercedes-benz':
        return '$baseUrl/mercedes-benz.png';
      case 'nissan':
        return '$baseUrl/nissan.png';
      case 'hyundai':
        return '$baseUrl/hyundai.png';
      case 'ford':
        return '$baseUrl/ford.png';
      case 'volkswagen':
        return '$baseUrl/volkswagen.png';
      case 'chevrolet':
        return '$baseUrl/chevrolet.png';
      case 'volvo':
        return '$baseUrl/volvo.png';
      case 'subaru':
        return '$baseUrl/subaru.png';
      case 'mazda':
        return '$baseUrl/mazda.png';
      case 'lexus':
        return '$baseUrl/lexus.png';
      case 'porsche':
        return '$baseUrl/porsche.png';
      case 'jaguar':
        return '$baseUrl/jaguar.png';
      case 'land rover':
        return '$baseUrl/land-rover.png';
      case 'jeep':
        return '$baseUrl/jeep.png';
      case 'dodge':
        return '$baseUrl/dodge.png';
      default:
        return '$baseUrl/toyota.png'; // Default fallback
    }
  }
}
