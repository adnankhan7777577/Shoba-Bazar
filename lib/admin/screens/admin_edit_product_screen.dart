import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/price_types.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';
import '../../controller/add_product/cubit.dart';
import '../../controller/add_product/state.dart';
import 'admin_add_product_screen.dart'; // For dialog classes

class AdminEditProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  
  const AdminEditProductScreen({
    super.key,
    this.product,
  });

  @override
  State<AdminEditProductScreen> createState() => _AdminEditProductScreenState();
}

class _AdminEditProductScreenState extends State<AdminEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  // Form state - using UUIDs
  String? _selectedCategoryId;
  String? _selectedTypeId;
  String? _selectedModelId;
  String? _selectedBrandId;
  String? _selectedPriceTypeCode;
  String _selectedUsage = 'New';
  String? _selectedOrigin;
  
  // Images: existing URLs and new files
  List<String> _existingImageUrls = [];
  List<File> _newProductImages = [];

  // Dropdown options from database
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _brands = [];
  
  bool _isLoadingOptions = true;
  bool _isEditMode = false;
  String? _productId;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.product != null;
    if (_isEditMode && widget.product != null) {
      try {
        _productId = widget.product!['id'] as String?;
        if (_productId != null) {
          _populateFormFromProduct();
          // Load images directly from database
          _loadProductImages();
        }
      } catch (e) {
        print('Error populating form from product: $e');
      }
    }
    // Load dropdown options after a frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDropdownOptions();
    });
  }

  Future<void> _loadProductImages() async {
    if (_productId == null) return;
    
    try {
      // Fetch product images directly from database, same as product detail screen
      final imagesResponse = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('product_id', _productId!)
          .order('display_order', ascending: true);

      final images = (imagesResponse as List)
          .map((img) => img['image_url'] as String)
          .toList();
      
      print('Loaded images from database: $images');
      
      if (mounted) {
        setState(() {
          _existingImageUrls = images;
        });
      }
    } catch (e) {
      print('Error loading product images: $e');
    }
  }

  void _populateFormFromProduct() {
    try {
      final product = widget.product!;
      if (product.isEmpty) return;
      
      // Set name
      _nameController.text = product['name'] as String? ?? '';
      
      // Set description
      _descriptionController.text = product['description'] as String? ?? '';
      
      // Set price
      final price = product['price'];
      if (price != null) {
        final priceValue = price is num ? price : (double.tryParse(price.toString()) ?? 0.0);
        _priceController.text = priceValue.toStringAsFixed(0);
      }
      
      // Set category
      _selectedCategoryId = product['category_id'] as String?;
      
      // Set type
      _selectedTypeId = product['type_id'] as String?;
      
      // Set brand
      _selectedBrandId = product['brand_id'] as String?;
      
      // Set model
      _selectedModelId = product['model_id'] as String?;
      
      
      // Set usage
      _selectedUsage = product['usage'] as String? ?? 'New';
      
      // Set origin
      _selectedOrigin = product['origin'] as String?;
      
      // Set price type code
      final priceType = product['price_types'];
      if (priceType is Map<String, dynamic>) {
        _selectedPriceTypeCode = priceType['name'] as String?;
      }
      
      // Images are loaded separately via _loadProductImages() method
      // which fetches directly from database, same as product detail screen
    } catch (e) {
      print('Error in _populateFormFromProduct: $e');
    }
  }

  Future<void> _loadDropdownOptions() async {
    if (!mounted) return;
    
    setState(() => _isLoadingOptions = true);
    
    try {
      final cubit = context.read<AddProductCubit>();
      
      final results = await Future.wait([
        cubit.fetchCategories(),
        cubit.fetchBrands(),
        cubit.fetchModels(),
      ]);

      if (mounted) {
        setState(() {
          _categories = results[0];
          _types = []; // Don't load all types initially
          _brands = results[1];
          _models = results[2];
          _isLoadingOptions = false;
        });
        
        // Load types for the selected category if category is already set
        if (_selectedCategoryId != null) {
          await _loadTypesForCategory(_selectedCategoryId!);
        }
      }
    } catch (e) {
      print('Error loading dropdown options: $e');
      if (mounted) {
        setState(() => _isLoadingOptions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading options: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadTypesForCategory(String categoryId) async {
    if (categoryId.isEmpty) {
      setState(() {
        _types = [];
        // Don't reset _selectedTypeId if we're editing, as it might be valid
      });
      return;
    }

    try {
      final cubit = context.read<AddProductCubit>();
      final types = await cubit.fetchTypes(categoryId: categoryId);
      if (mounted) {
        setState(() {
          _types = types;
          // Reset type selection if current type is not in the new list
          if (_selectedTypeId != null) {
            final typeExists = types.any((type) => type['id'] == _selectedTypeId);
            if (!typeExists) {
              _selectedTypeId = null;
            }
          }
        });
      }
    } catch (e) {
      print('Error loading types for category: $e');
      if (mounted) {
        setState(() {
          _types = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Safety check: if in edit mode but no product data, show error
    if (_isEditMode && (widget.product == null || widget.product!.isEmpty)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Product data not available',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 8),
              Text(
                'Please go back and try again',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    return BlocConsumer<AddProductCubit, AddProductState>(
      listener: (context, state) {
        if (state is AddProductSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Navigate back after a short delay to ensure snackbar is shown
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          });
        } else if (state is AddProductError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AddProductLoading;
        
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _isLoadingOptions
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name Section
                        _buildNameSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Category Section
                        _buildCategorySection(),
                        
                        const SizedBox(height: 24),
                        
                        // Type Section
                        _buildTypeSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Description Section
                        _buildDescriptionSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Usage and Origin Section
                        _buildUsageAndOriginSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Price Section
                        _buildPriceSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Images Section
                        _buildImagesSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Related Vehicle Section
                        _buildRelatedVehicleSection(),
                        
                        const SizedBox(height: 32),
                        
                        // Update Button
                        _buildUpdateButton(isLoading),
                        const SizedBox(height: 10),
                        _buildDeleteButton(),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.adminPrimary,
      foregroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Edit product',
        style: AppTextStyles.heading2.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Product Name',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: AppColors.error, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _nameController,
          hintText: 'Enter product name',
          borderColor: AppColors.adminPrimary,
          onChanged: (_) => setState(() {}),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter product name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final categoryNames = _categories.map((e) => e['name'] as String).toList();
    final selectedCategoryName = _categories
        .firstWhere((e) => e['id'] == _selectedCategoryId, orElse: () => {})['name'] as String?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Category',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: AppColors.error, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomDropdown(
                value: selectedCategoryName,
                hintText: 'Select Category',
                items: categoryNames,
                borderColor: AppColors.adminPrimary,
                onChanged: (value) async {
                  if (value != null) {
                    final category = _categories.firstWhere((e) => e['name'] == value);
                    final categoryId = category['id'] as String;
                    setState(() {
                      _selectedCategoryId = categoryId;
                      _selectedTypeId = null; // Reset type when category changes
                    });
                    // Reload types for the selected category
                    await _loadTypesForCategory(categoryId);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showAddCategoryDialog(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.adminPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSection() {
    // Show message if category is not selected
    if (_selectedCategoryId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Type',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: AppColors.error, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.lightGrey),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please select a category first',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final typeNames = _types.map((e) => e['name'] as String).toList();
    final selectedTypeName = _types
        .firstWhere((e) => e['id'] == _selectedTypeId, orElse: () => {})['name'] as String?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Type',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: AppColors.error, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomDropdown(
                value: selectedTypeName,
                hintText: typeNames.isEmpty ? 'No types available' : 'Select Type',
                items: typeNames,
                borderColor: AppColors.adminPrimary,
                onChanged: (value) {
                  if (value != null) {
                    final type = _types.firstWhere((e) => e['name'] == value);
                    setState(() {
                      _selectedTypeId = type['id'] as String;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showAddTypeDialog(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.adminPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Description',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: AppColors.error, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.adminPrimary, width: 1),
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Enter product description',
              hintStyle: AppTextStyles.textFieldHint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter description';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUsageAndOriginSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                'Usage',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      'New',
                      _selectedUsage == 'New',
                      () => setState(() => _selectedUsage = 'New'),
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToggleButton(
                      'Used',
                      _selectedUsage == 'Used',
                      () => setState(() => _selectedUsage = 'Used'),
                      AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              Text(
                'Origin',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      'Imported',
                      _selectedOrigin == 'Imported',
                      () => setState(() => _selectedOrigin = 'Imported'),
                      AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToggleButton(
                      'Local',
                      _selectedOrigin == 'Local',
                      () => setState(() => _selectedOrigin = 'Local'),
                      AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.lightGrey,
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? color : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    final currencyDisplayNames = PriceTypes.allDisplayNames;
    final selectedDisplayName = _selectedPriceTypeCode != null
        ? PriceTypes.getDisplayName(_selectedPriceTypeCode!)
        : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Price',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: AppColors.error, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: CustomDropdown(
                value: selectedDisplayName,
                hintText: 'Currency',
                items: currencyDisplayNames,
                borderColor: AppColors.adminPrimary,
                onChanged: (value) {
                  if (value != null) {
                    final currencyCode = PriceTypes.getCurrencyCode(value);
                    setState(() {
                      _selectedPriceTypeCode = currencyCode;
                    });
                  } else {
                    setState(() {
                      _selectedPriceTypeCode = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: CustomTextField(
                controller: _priceController,
                hintText: '20,000',
                keyboardType: TextInputType.number,
                borderColor: AppColors.adminPrimary,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagesSection() {
    final totalImages = _existingImageUrls.length + _newProductImages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Images',
              style: AppTextStyles.heading3,
            ),
            Text(
              '$totalImages/5',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: totalImages + 1,
            itemBuilder: (context, index) {
              if (index == totalImages) {
                return _buildAddImageButton();
              }
              if (index < _existingImageUrls.length) {
                return _buildExistingImageThumbnail(_existingImageUrls[index], index);
              } else {
                final newImageIndex = index - _existingImageUrls.length;
                return _buildImageThumbnail(_newProductImages[newImageIndex], index);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton() {
    final totalImages = _existingImageUrls.length + _newProductImages.length;
    if (totalImages >= 5) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: _addImage,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.adminPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.add,
          color: AppColors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildExistingImageThumbnail(String imageUrl, int index) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.image),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeExistingImage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: AppColors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(File imageFile, int index) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              imageFile,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeNewImage(index - _existingImageUrls.length),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: AppColors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newProductImages.removeAt(index);
    });
  }

  Widget _buildRelatedVehicleSection() {
    final brandNames = _brands.map((e) => e['name'] as String).toList();
    final selectedBrandName = _brands
        .firstWhere((e) => e['id'] == _selectedBrandId, orElse: () => {})['name'] as String?;
    
    final modelNames = _models.map((e) => e['name'] as String).toList();
    final selectedModelName = _models
        .firstWhere((e) => e['id'] == _selectedModelId, orElse: () => {})['name'] as String?;
    
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Vehicle',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: 16),
        
        // Brand Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Brand',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomDropdown(
                    value: selectedBrandName,
                    hintText: 'Select Brand',
                    items: brandNames,
                    borderColor: AppColors.adminPrimary,
                    onChanged: (value) {
                      if (value != null) {
                        final brand = _brands.firstWhere((e) => e['name'] == value);
                        setState(() {
                          _selectedBrandId = brand['id'] as String;
                        });
                      } else {
                        setState(() {
                          _selectedBrandId = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showAddBrandDialog(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.adminPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Model Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Model',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomDropdown(
                    value: selectedModelName,
                    hintText: 'Select Model',
                    items: modelNames,
                    borderColor: AppColors.adminPrimary,
                    onChanged: (value) {
                      if (value != null) {
                        final model = _models.firstWhere((e) => e['name'] == value);
                        setState(() {
                          _selectedModelId = model['id'] as String;
                        });
                      } else {
                        setState(() {
                          _selectedModelId = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showAddModelDialog(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.adminPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
      ],
    );
  }

  Widget _buildUpdateButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: AppColors.white,
          elevation: 4,
          shadowColor: AppColors.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppColors.lightGrey,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimaryLight),
                ),
              )
            : Text(
                'Update Product',
                style: AppTextStyles.primaryButton.copyWith(
                  color: AppColors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton(
        onPressed: _showDeleteConfirmationDialog,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.adminPrimary,
          side: const BorderSide(color: AppColors.adminPrimary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          'Delete',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.adminPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    if (!_isEditMode || _productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid product data'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Validate all required fields
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter product name'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a category'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedTypeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a type'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_descriptionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter description'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedOrigin == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select origin'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedBrandId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a brand'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedModelId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a model'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_priceController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter price'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedPriceTypeCode == null || _selectedPriceTypeCode!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select currency'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_existingImageUrls.isEmpty && _newProductImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one image'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Call update product
      context.read<AddProductCubit>().updateProduct(
        productId: _productId!,
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        typeId: _selectedTypeId!,
        brandId: _selectedBrandId!,
        modelId: _selectedModelId!,
        description: _descriptionController.text.trim(),
        usage: _selectedUsage,
        origin: _selectedOrigin!,
        price: _priceController.text.trim(),
        priceTypeCode: _selectedPriceTypeCode!,
        newProductImages: _newProductImages,
        imageUrlsToKeep: _existingImageUrls,
      );
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.adminPrimary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: AppColors.adminPrimary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Product',
                  style: AppTextStyles.heading2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this product? This action cannot be undone.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.lightGrey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteProduct();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.adminPrimary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Delete',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteProduct() {
    if (_productId == null) return;
    
    context.read<AddProductCubit>().deleteProduct(_productId!);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Product deleted successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    
    // Navigate back to dashboard
    Navigator.pop(context);
  }

  // Image picker methods
  void _addImage() async {
    final totalImages = _existingImageUrls.length + _newProductImages.length;
    if (totalImages >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 images allowed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Image Source',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.adminPrimary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      
      if (source == ImageSource.gallery) {
        final List<XFile> images = await picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (images.isNotEmpty) {
          int remainingSlots = 5 - (_existingImageUrls.length + _newProductImages.length);
          int imagesToAdd = images.length > remainingSlots ? remainingSlots : images.length;
          
          setState(() {
            for (int i = 0; i < imagesToAdd; i++) {
              _newProductImages.add(File(images[i].path));
            }
          });
          
          if (imagesToAdd < images.length) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Only $imagesToAdd images added. Maximum 5 images allowed.'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      } else {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          final totalImages = _existingImageUrls.length + _newProductImages.length;
          if (totalImages >= 5) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Maximum 5 images allowed'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          
          setState(() {
            _newProductImages.add(File(image.path));
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Dialog methods
  void _showAddCategoryDialog() async {
    await showDialog<String>(
      context: context,
      builder: (context) => AddCategoryWithImageDialog(
        title: 'Add Category',
        hintText: 'Enter new category',
        existingItems: _categories.map((e) => e['name'] as String).toList(),
        onItemAdded: (category, imageFile) async {
          final cubit = context.read<AddProductCubit>();
          final id = await cubit.addCategory(category, imageFile: imageFile);
          if (id != null && mounted) {
            // Reload categories
            final categories = await cubit.fetchCategories();
            if (mounted) {
              setState(() {
                _categories = categories;
                _selectedCategoryId = id;
              });
            }
          }
        },
      ),
    );
  }

  void _showAddTypeDialog() async {
    await showDialog<String>(
      context: context,
      builder: (context) => AddTypeWithCategoryDialog(
        title: 'Add Type',
        hintText: 'Enter new type',
        categories: _categories, // Pass all categories
        initialCategoryId: _selectedCategoryId, // Pass current category if selected
        existingItems: _types.map((e) => e['name'] as String).toList(),
        onItemAdded: (type, categoryIds) async {
          final cubit = context.read<AddProductCubit>();
          final id = await cubit.addType(type, categoryIds: categoryIds);
          if (id != null && mounted) {
            // If any of the selected categories matches the currently selected category, reload types
            if (categoryIds.contains(_selectedCategoryId)) {
              final types = await cubit.fetchTypes(categoryId: _selectedCategoryId);
              if (mounted) {
                setState(() {
                  _types = types;
                  final newType = types.firstWhere((e) => e['name'] == type);
                  _selectedTypeId = newType['id'] as String;
                });
              }
            }
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showAddBrandDialog() async {
    await showDialog<String>(
      context: context,
      builder: (context) => AddBrandWithImageDialog(
        title: 'Add Brand',
        hintText: 'Enter new brand',
        existingItems: _brands.map((e) => e['name'] as String).toList(),
        onItemAdded: (brand, imageFile) async {
          final cubit = context.read<AddProductCubit>();
          final id = await cubit.addBrand(brand, imageFile: imageFile);
          if (id != null && mounted) {
            // Reload brands
            final brands = await cubit.fetchBrands();
            if (mounted) {
              setState(() {
                _brands = brands;
                _selectedBrandId = id;
              });
            }
          }
        },
      ),
    );
  }

  void _showAddModelDialog() async {
    await showDialog<String>(
      context: context,
      builder: (context) => AddNewItemDialog(
        title: 'Add Model',
        hintText: 'Enter new model',
        existingItems: _models.map((e) => e['name'] as String).toList(),
        onItemAdded: (model) async {
          final cubit = context.read<AddProductCubit>();
          final id = await cubit.addModel(model);
          if (id != null && mounted) {
            // Reload models
            final models = await cubit.fetchModels();
            if (mounted) {
              setState(() {
                _models = models;
                _selectedModelId = id;
              });
            }
          }
        },
      ),
    );
  }

}
