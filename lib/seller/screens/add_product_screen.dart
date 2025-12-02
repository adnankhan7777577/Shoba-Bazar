import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/price_types.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_snackbar.dart';
import '../../controller/add_product/cubit.dart';
import '../../controller/add_product/state.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  // Form state - using UUIDs
  String? _selectedCategoryId;
  String? _selectedTypeId;
  String? _selectedModelId;
  String? _selectedBrandId;
  String? _selectedPriceTypeCode; // Store currency code instead of ID
  String _selectedUsage = 'New'; // Changed from _selectedClass
  String? _selectedOrigin;
  List<File> _productImages = [];

  // Dropdown options from database
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _brands = [];
  
  bool _isLoadingOptions = true;

  @override
  void initState() {
    super.initState();
    _loadDropdownOptions();
  }

  Future<void> _loadDropdownOptions() async {
    setState(() => _isLoadingOptions = true);
    final cubit = context.read<AddProductCubit>();
    
    try {
      final results = await Future.wait([
        cubit.fetchCategories(),
        cubit.fetchBrands(),
        cubit.fetchModels(),
      ]);

      setState(() {
        _categories = results[0];
        _types = []; // Don't load all types initially, wait for category selection
        _brands = results[1];
        _models = results[2];
        _isLoadingOptions = false;
      });
    } catch (e) {
      setState(() => _isLoadingOptions = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading options: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
    return BlocConsumer<AddProductCubit, AddProductState>(
      listener: (context, state) {
        if (state is AddProductSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
          // Clear form and navigate back
          _clearForm();
          Navigator.pop(context);
        } else if (state is AddProductError) {
          // Check if it's a network error and show appropriate message
          if (state.message.contains('No internet connection') || 
              state.message.contains('network') ||
              state.message.contains('connection')) {
            CustomSnackBar.showNoNetwork(context, message: state.message);
          } else {
            CustomSnackBar.showError(context, state.message);
          }
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
                  ? const Center(child: CircularProgressIndicator())
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
                        
                        // Add Button
                        _buildAddButton(isLoading),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  void _clearForm() {
    _selectedCategoryId = null;
    _selectedTypeId = null;
    _selectedModelId = null;
    _selectedBrandId = null;
    _selectedPriceTypeCode = null;
    _selectedUsage = 'New';
    _selectedOrigin = null;
    _productImages.clear();
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _formKey.currentState?.reset();
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
          onChanged: (_) => setState(() {}), // Rebuild to update button state
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      title: Text(
        'Add a product',
        style: AppTextStyles.heading2.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
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
                  color: AppColors.primary,
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
                  color: AppColors.primary,
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
            border: Border.all(color: AppColors.primary, width: 1),
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
            onChanged: (_) => setState(() {}), // Rebuild to update button state
            decoration: InputDecoration(
              hintText: 'Upgrade your vehicle\'s style and performance with our premium 18-inch alloy rims. Crafted from high-quality materials, these rims are designed to provide exceptional strength while maintaining a lightweight build for smoother handling.',
              hintStyle: AppTextStyles.textFieldHint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageAndOriginSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Usage & Origin',
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
                          AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToggleButton(
                          'Used',
                          _selectedUsage == 'Used',
                          () => setState(() => _selectedUsage = 'Used'),
                          AppColors.success,
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
    // Use hardcoded currency list from constants
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
                onChanged: (_) => setState(() {}), // Rebuild to update button state
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Images',
                  style: AppTextStyles.heading3,
                ),
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: AppColors.error, fontSize: 16),
                ),
              ],
            ),
            Text(
              '${_productImages.length}/5',
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
            itemCount: _productImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _productImages.length) {
                return _buildAddImageButton();
              }
              return _buildImageThumbnail(_productImages[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _addImage,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
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
              onTap: () => _removeImage(index),
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

  Widget _buildRelatedVehicleSection() {
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
                    value: _brands
                        .firstWhere((e) => e['id'] == _selectedBrandId, orElse: () => {})['name'] as String?,
                    hintText: 'Select Brand',
                    items: _brands.map((e) => e['name'] as String).toList(),
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
                      color: AppColors.primary,
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
                      color: AppColors.primary,
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

  bool _isFormValid() {
    return _nameController.text.trim().isNotEmpty &&
        _selectedCategoryId != null &&
        _selectedTypeId != null &&
        _descriptionController.text.trim().isNotEmpty &&
        _selectedOrigin != null &&
        _selectedBrandId != null &&
        _selectedModelId != null &&
        _priceController.text.trim().isNotEmpty &&
        _selectedPriceTypeCode != null &&
        _selectedPriceTypeCode!.isNotEmpty &&
        _productImages.isNotEmpty;
  }

  Widget _buildAddButton(bool isLoading) {
    final isFormValid = _isFormValid();
    return AppButton.primary(
      text: 'Add',
      onPressed: (isLoading || !isFormValid) ? null : _submitForm,
      isLoading: isLoading,
    );
  }

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
                final newCategory = categories.firstWhere((e) => e['name'] == category);
                _selectedCategoryId = newCategory['id'] as String;
              });
            }
            Navigator.pop(context);
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

  Future<void> _loadTypesForCategory(String categoryId) async {
    if (categoryId.isEmpty) {
      setState(() {
        _types = [];
        _selectedTypeId = null;
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
          _selectedTypeId = null;
        });
      }
    }
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
                final newBrand = brands.firstWhere((e) => e['name'] == brand);
                _selectedBrandId = newBrand['id'] as String;
              });
            }
            Navigator.pop(context);
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
                final newModel = models.firstWhere((e) => e['name'] == model);
                _selectedModelId = newModel['id'] as String;
              });
            }
            Navigator.pop(context);
          }
        },
      ),
    );
  }


  void _addImage() async {
    if (_productImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 images allowed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    // Show image source selection dialog
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
            // Handle bar
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
            
            const SizedBox(height: 8),
            
            Text(
              'Gallery allows multiple selection',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
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
              color: AppColors.primary,
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
        // Multiple selection for gallery
        final List<XFile> images = await picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (images.isNotEmpty) {
          // Check if adding these images would exceed the limit
          int remainingSlots = 5 - _productImages.length;
          int imagesToAdd = images.length > remainingSlots ? remainingSlots : images.length;
          
          setState(() {
            for (int i = 0; i < imagesToAdd; i++) {
              _productImages.add(File(images[i].path));
            }
          });
          
          if (imagesToAdd < images.length) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Only $imagesToAdd images added. Maximum 5 images allowed.'),
                backgroundColor: AppColors.warning,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${imagesToAdd} image${imagesToAdd > 1 ? 's' : ''} added successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } else {
        // Single selection for camera
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          setState(() {
            _productImages.add(File(image.path));
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image added successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
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

  void _removeImage(int index) {
    setState(() {
      _productImages.removeAt(index);
    });
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate required fields
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
          content: Text('Please enter a description'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedOrigin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select origin (Imported or Local)'),
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
          content: Text('Please enter a price'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedPriceTypeCode == null || _selectedPriceTypeCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a currency'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_productImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product image'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Submit product - all fields are required at this point
    context.read<AddProductCubit>().addProduct(
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
      productImages: _productImages,
    );
  }
}

// Dialog for adding category and type together
class AddCategoryAndTypeDialog extends StatefulWidget {
  final List<String> existingCategories;
  final Function(String) onCategoryAdded;

  const AddCategoryAndTypeDialog({
    super.key,
    required this.existingCategories,
    required this.onCategoryAdded,
  });

  @override
  State<AddCategoryAndTypeDialog> createState() => _AddCategoryAndTypeDialogState();
}

class _AddCategoryAndTypeDialogState extends State<AddCategoryAndTypeDialog> {
  final _categoryController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Category',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _categoryController,
              hintText: 'Enter new category',
            ),
            const SizedBox(height: 24),
            AppButton.primary(
              text: 'Add',
              onPressed: _addItems,
            ),
          ],
        ),
      ),
    );
  }

  void _addItems() {
    if (_categoryController.text.isNotEmpty) {
      widget.onCategoryAdded(_categoryController.text.trim());
      Navigator.pop(context);
    }
  }
}

// Dialog for adding a new item (brand, model, year, type, category)
class AddNewItemDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final List<String> existingItems;
  final Future<void> Function(String) onItemAdded;

  const AddNewItemDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.existingItems,
    required this.onItemAdded,
  });

  @override
  State<AddNewItemDialog> createState() => _AddNewItemDialogState();
}

class _AddNewItemDialogState extends State<AddNewItemDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: _isLoading ? null : () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _controller,
              hintText: widget.hintText,
            ),
            const SizedBox(height: 24),
            AppButton.primary(
              text: 'Add',
              onPressed: (_hasText && !_isLoading) ? _addItem : null,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    if (_controller.text.trim().isEmpty) return;
    
    final itemName = _controller.text.trim();
    
    // Validate: Model must be an integer
    if (widget.title.toLowerCase().contains('model')) {
      if (!_isInteger(itemName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Model must be an integer value. Please enter a valid number.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }
    
    // Check if item already exists
    if (widget.existingItems.any((item) => item.toLowerCase() == itemName.toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} "$itemName" already exists'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await widget.onItemAdded(itemName);
      // Dialog will be closed by the onItemAdded callback
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to check if string is a valid integer
  bool _isInteger(String text) {
    if (text.isEmpty) return false;
    // Remove any whitespace
    final trimmed = text.trim();
    // Check if it's a valid integer (can be negative)
    return RegExp(r'^-?\d+$').hasMatch(trimmed);
  }
}

// Dialog for adding type with category selection
class AddTypeWithCategoryDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final List<Map<String, dynamic>> categories; // All categories to select from
  final String? initialCategoryId; // Optional initial category selection
  final List<String> existingItems;
  final Future<void> Function(String, List<String>) onItemAdded; // Changed to accept list of category IDs

  const AddTypeWithCategoryDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.categories,
    this.initialCategoryId,
    required this.existingItems,
    required this.onItemAdded,
  });

  @override
  State<AddTypeWithCategoryDialog> createState() => _AddTypeWithCategoryDialogState();
}

class _AddTypeWithCategoryDialogState extends State<AddTypeWithCategoryDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _hasText = false;
  Set<String> _selectedCategoryIds = {}; // Changed to Set for multiple selection

  @override
  void initState() {
    super.initState();
    // Set initial category if provided
    if (widget.initialCategoryId != null) {
      _selectedCategoryIds.add(widget.initialCategoryId!);
    }
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: _isLoading ? null : () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 24),
            // Category Selection with Checkboxes
            Text(
              'Category',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: widget.categories.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No categories available'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.categories.length,
                      itemBuilder: (context, index) {
                        final category = widget.categories[index];
                        final categoryId = category['id'] as String;
                        final categoryName = category['name'] as String;
                        final isSelected = _selectedCategoryIds.contains(categoryId);
                        
                        return CheckboxListTile(
                          title: Text(categoryName),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedCategoryIds.add(categoryId);
                              } else {
                                _selectedCategoryIds.remove(categoryId);
                              }
                            });
                          },
                          activeColor: AppColors.primary,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _controller,
              hintText: widget.hintText,
            ),
            const SizedBox(height: 24),
            AppButton.primary(
              text: 'Add',
              onPressed: (_hasText && _selectedCategoryIds.isNotEmpty && !_isLoading) ? _addItem : null,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    if (_controller.text.trim().isEmpty || _selectedCategoryIds.isEmpty) return;
    
    final itemName = _controller.text.trim();
    
    // Validate: Name must be text (not just numbers)
    if (_isOnlyNumbers(itemName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Type name cannot be only numbers. Please enter a text name.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Note: We don't check existingItems here because the same type name
    // can exist in multiple categories. The cubit will handle checking
    // which categories already have this type and only add it to new ones.

    setState(() => _isLoading = true);
    
    try {
      await widget.onItemAdded(itemName, _selectedCategoryIds.toList());
      // Dialog will be closed by the onItemAdded callback
      if (mounted && _selectedCategoryIds.length > 1) {
        // Show success message if multiple categories were selected
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Type "$itemName" was successfully added to ${_selectedCategoryIds.length} categories.'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to check if string contains only numbers
  bool _isOnlyNumbers(String text) {
    if (text.isEmpty) return false;
    // Check if the text contains only digits (and possibly spaces)
    final numericOnly = text.replaceAll(RegExp(r'\s+'), '');
    return numericOnly.isNotEmpty && numericOnly.split('').every((char) => RegExp(r'^\d+$').hasMatch(char));
  }
}

// Dialog for adding brand with image upload
class AddBrandDialog extends StatefulWidget {
  final Function(String) onItemAdded;

  const AddBrandDialog({
    super.key,
    required this.onItemAdded,
  });

  @override
  State<AddBrandDialog> createState() => _AddBrandDialogState();
}

class _AddBrandDialogState extends State<AddBrandDialog> {
  final _controller = TextEditingController();
  File? _brandImage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Brand',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _controller,
              hintText: 'Enter brand name',
            ),
            const SizedBox(height: 20),
            Text(
              'Brand Image',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selectImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.lightGrey,
                    width: 2,
                  ),
                ),
                child: _brandImage != null
                    ? ClipOval(
                        child: Image.file(
                          _brandImage!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.branding_watermark,
                            color: AppColors.primary,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Brand',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            AppButton.primary(
              text: 'Add',
              onPressed: _controller.text.isNotEmpty ? _addItem : null,
            ),
          ],
        ),
      ),
    );
  }

  void _selectImage() async {
    // Show image source selection dialog
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
              color: AppColors.primary,
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
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _brandImage = File(image.path);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Brand image selected successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
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

  void _addItem() {
    if (_controller.text.isNotEmpty) {
      widget.onItemAdded(_controller.text.trim());
      Navigator.pop(context);
    }
  }
}

// Dialog for adding category with image
class AddCategoryWithImageDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final List<String> existingItems;
  final Future<void> Function(String, File?) onItemAdded;

  const AddCategoryWithImageDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.existingItems,
    required this.onItemAdded,
  });

  @override
  State<AddCategoryWithImageDialog> createState() => _AddCategoryWithImageDialogState();
}

class _AddCategoryWithImageDialogState extends State<AddCategoryWithImageDialog> {
  final _controller = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addItem() async {
    if (_controller.text.trim().isEmpty) return;
    
    final itemName = _controller.text.trim();
    
    // Validate: Name must be text (not just numbers)
    if (_isOnlyNumbers(itemName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category name cannot be only numbers. Please enter a text name.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Validate: Image is required
    if (_selectedImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category image is required'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Check if item already exists
    if (widget.existingItems.any((item) => item.toLowerCase() == itemName.toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This item already exists'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await widget.onItemAdded(itemName, _selectedImage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to check if string contains only numbers
  bool _isOnlyNumbers(String text) {
    if (text.isEmpty) return false;
    // Check if the text contains only digits (and possibly spaces)
    final numericOnly = text.replaceAll(RegExp(r'\s+'), '');
    return numericOnly.isNotEmpty && numericOnly.split('').every((char) => RegExp(r'^\d+$').hasMatch(char));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: _isLoading ? null : () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _controller,
              hintText: widget.hintText,
            ),
            const SizedBox(height: 24),
            // Image upload section
            Text(
              'Image (Required)',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.lightGrey,
                    width: 2,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Image',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImage = null;
                  });
                },
                child: Text(
                  'Remove Image',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            AppButton.primary(
              text: 'Add',
              onPressed: (_controller.text.trim().isNotEmpty && !_isLoading) ? _addItem : null,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog for adding brand with image
class AddBrandWithImageDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final List<String> existingItems;
  final Future<void> Function(String, File?) onItemAdded;

  const AddBrandWithImageDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.existingItems,
    required this.onItemAdded,
  });

  @override
  State<AddBrandWithImageDialog> createState() => _AddBrandWithImageDialogState();
}

class _AddBrandWithImageDialogState extends State<AddBrandWithImageDialog> {
  final _controller = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addItem() async {
    if (_controller.text.trim().isEmpty) return;
    
    final itemName = _controller.text.trim();
    
    // Validate: Name must be text (not just numbers)
    if (_isOnlyNumbers(itemName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Brand name cannot be only numbers. Please enter a text name.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Validate: Image is required
    if (_selectedImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Brand image is required'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Check if item already exists
    if (widget.existingItems.any((item) => item.toLowerCase() == itemName.toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This item already exists'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await widget.onItemAdded(itemName, _selectedImage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to check if string contains only numbers
  bool _isOnlyNumbers(String text) {
    if (text.isEmpty) return false;
    // Check if the text contains only digits (and possibly spaces)
    final numericOnly = text.replaceAll(RegExp(r'\s+'), '');
    return numericOnly.isNotEmpty && numericOnly.split('').every((char) => RegExp(r'^\d+$').hasMatch(char));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: _isLoading ? null : () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _controller,
              hintText: widget.hintText,
            ),
            const SizedBox(height: 24),
            // Image upload section
            Text(
              'Image (Required)',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.lightGrey,
                    width: 2,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Image',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImage = null;
                  });
                },
                child: Text(
                  'Remove Image',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            AppButton.primary(
              text: 'Add',
              onPressed: (_controller.text.trim().isNotEmpty && !_isLoading) ? _addItem : null,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
