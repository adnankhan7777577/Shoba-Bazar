import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/product_metadata_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_snackbar.dart';

class ProductMetadataManagementScreen extends StatefulWidget {
  final bool isAdmin;
  
  const ProductMetadataManagementScreen({
    super.key,
    this.isAdmin = false,
  });

  @override
  State<ProductMetadataManagementScreen> createState() => _ProductMetadataManagementScreenState();
}

class _ProductMetadataManagementScreenState extends State<ProductMetadataManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductMetadataService _service = ProductMetadataService();
  final ImagePicker _imagePicker = ImagePicker();

  // Data lists
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _models = [];
  
  // All categories (for adding types - sellers can add types to any category)
  List<Map<String, dynamic>> _allCategories = [];

  bool _isLoading = false;

  Color get _primaryColor => widget.isAdmin ? AppColors.adminPrimary : AppColors.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        // For sellers: only fetch categories they created
        // For admin: fetch all categories
        _service.fetchCategories(isAdmin: widget.isAdmin),
        // For sellers: only fetch brands they created
        // For admin: fetch all brands
        _service.fetchBrands(isAdmin: widget.isAdmin),
        // For sellers: only fetch types they created
        // For admin: fetch all types
        _service.fetchTypes(isAdmin: widget.isAdmin),
        // For sellers: only fetch models they created
        // For admin: fetch all models
        _service.fetchModels(isAdmin: widget.isAdmin),
        // Fetch ALL categories (for adding types - sellers can add types to any category)
        _service.fetchAllCategories(),
      ]);

      setState(() {
        _categories = results[0]; // Seller's categories only (or all for admin)
        _brands = results[1]; // Seller's brands only (or all for admin)
        _types = results[2]; // Seller's types only (or all for admin)
        _models = results[3]; // Seller's models only (or all for admin)
        _allCategories = results[4]; // All categories (for adding types dialog)
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomSnackBar.showError(context, 'Error loading data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Manage Product Data',
          style: AppTextStyles.heading2.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Brands'),
            Tab(text: 'Types'),
            Tab(text: 'Models'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoriesTab(),
                _buildBrandsTab(),
                _buildTypesTab(),
                _buildModelsTab(),
              ],
            ),
    );
  }

  // ============ CATEGORIES TAB ============
  Widget _buildCategoriesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories (${_categories.length})',
                style: AppTextStyles.heading3,
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _categories.isEmpty
              ? Center(
                  child: Text(
                    'No categories found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return _buildCategoryCard(category);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final imageUrl = category['image'] as String?;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: imageUrl != null && imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    width: 50,
                    height: 50,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.image),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category),
              ),
        title: Text(
          category['name'] as String? ?? '',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              color: _primaryColor,
              onPressed: () => _showEditCategoryDialog(category),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: AppColors.error,
              onPressed: () => _showDeleteCategoryDialog(category),
            ),
          ],
        ),
      ),
    );
  }

  // ============ BRANDS TAB ============
  Widget _buildBrandsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Brands (${_brands.length})',
                style: AppTextStyles.heading3,
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddBrandDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Brand'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _brands.isEmpty
              ? Center(
                  child: Text(
                    'No brands found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _brands.length,
                  itemBuilder: (context, index) {
                    final brand = _brands[index];
                    return _buildBrandCard(brand);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBrandCard(Map<String, dynamic> brand) {
    final imageUrl = brand['image'] as String?;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: imageUrl != null && imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    width: 50,
                    height: 50,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.image),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.branding_watermark),
              ),
        title: Text(
          brand['name'] as String? ?? '',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              color: _primaryColor,
              onPressed: () => _showEditBrandDialog(brand),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: AppColors.error,
              onPressed: () => _showDeleteBrandDialog(brand),
            ),
          ],
        ),
      ),
    );
  }

  // ============ TYPES TAB ============
  Widget _buildTypesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Types (${_types.length})',
                style: AppTextStyles.heading3,
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddTypeDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Type'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _types.isEmpty
              ? Center(
                  child: Text(
                    'No types found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _types.length,
                  itemBuilder: (context, index) {
                    final type = _types[index];
                    return _buildTypeCard(type);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTypeCard(Map<String, dynamic> type) {
    final categoryData = type['product_categories'] as Map<String, dynamic>?;
    final categoryName = categoryData?['name'] as String? ?? 'No Category';
    
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.category, color: _primaryColor),
        ),
        title: Text(
          type['name'] as String? ?? '',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Category: $categoryName',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              color: _primaryColor,
              onPressed: () => _showEditTypeDialog(type),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: AppColors.error,
              onPressed: () => _showDeleteTypeDialog(type),
            ),
          ],
        ),
      ),
    );
  }

  // ============ MODELS TAB ============
  Widget _buildModelsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Models (${_models.length})',
                style: AppTextStyles.heading3,
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddModelDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _models.isEmpty
              ? Center(
                  child: Text(
                    'No models found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _models.length,
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    return _buildModelCard(model);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModelCard(Map<String, dynamic> model) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.directions_car, color: _primaryColor),
        ),
        title: Text(
          model['name'] as String? ?? '',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              color: _primaryColor,
              onPressed: () => _showEditModelDialog(model),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: AppColors.error,
              onPressed: () => _showDeleteModelDialog(model),
            ),
          ],
        ),
      ),
    );
  }


  // ============ DIALOGS FOR CATEGORIES ============
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    File? selectedImage;
    String? imageUrl;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  title: 'Category Name',
                  hintText: 'Enter category name',
                  controller: nameController,
                  borderColor: _primaryColor,
                ),
                const SizedBox(height: 20),
                // Image preview
                if (selectedImage != null || imageUrl != null)
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.lightGrey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: selectedImage != null
                          ? Image.file(selectedImage!, fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showImagePickerOptions(
                    onImageSelected: (file) {
                      setDialogState(() {
                        selectedImage = file;
                        imageUrl = null;
                      });
                    },
                  ),
                  icon: const Icon(Icons.image),
                  label: Text(selectedImage != null || imageUrl != null ? 'Change Image' : 'Add Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  CustomSnackBar.showError(context, 'Please enter category name');
                  return;
                }
                // Validate: Name must be text (not just numbers)
                if (_isOnlyNumbers(name)) {
                  CustomSnackBar.showError(context, 'Category name cannot be only numbers. Please enter a text name.');
                  return;
                }
                // Validate: Image is required
                if (selectedImage == null) {
                  CustomSnackBar.showError(context, 'Please upload a category image');
                  return;
                }
                Navigator.pop(context);
                try {
                  await _addCategory(name, selectedImage);
                } catch (e) {
                  if (mounted) {
                    CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(Map<String, dynamic> category) {
    final nameController = TextEditingController(text: category['name'] as String? ?? '');
    File? selectedImage;
    String? existingImageUrl = category['image'] as String?;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  title: 'Category Name',
                  hintText: 'Enter category name',
                  controller: nameController,
                  borderColor: _primaryColor,
                ),
                const SizedBox(height: 20),
                // Image preview
                if (selectedImage != null || existingImageUrl != null)
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.lightGrey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: selectedImage != null
                          ? Image.file(selectedImage!, fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: existingImageUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showImagePickerOptions(
                    onImageSelected: (file) {
                      setDialogState(() {
                        selectedImage = file;
                      });
                    },
                  ),
                  icon: const Icon(Icons.image),
                  label: Text(selectedImage != null || existingImageUrl != null ? 'Change Image' : 'Add Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  CustomSnackBar.showError(context, 'Please enter category name');
                  return;
                }
                // Validate: Name must be text (not just numbers)
                if (_isOnlyNumbers(name)) {
                  CustomSnackBar.showError(context, 'Category name cannot be only numbers. Please enter a text name.');
                  return;
                }
                // Validate: Image is required (either existing or new)
                if (selectedImage == null && (existingImageUrl == null || existingImageUrl.isEmpty)) {
                  CustomSnackBar.showError(context, 'Please upload a category image');
                  return;
                }
                Navigator.pop(context);
                try {
                  await _updateCategory(
                    category['id'] as String,
                    name,
                    selectedImage,
                    existingImageUrl,
                  );
                } catch (e) {
                  if (mounted) {
                    CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCategoryDialog(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCategory(
                category['id'] as String,
                category['image'] as String?,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ============ DIALOGS FOR BRANDS ============
  void _showAddBrandDialog() {
    final nameController = TextEditingController();
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add Brand'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  title: 'Brand Name',
                  hintText: 'Enter brand name',
                  controller: nameController,
                  borderColor: _primaryColor,
                ),
                const SizedBox(height: 20),
                if (selectedImage != null)
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.lightGrey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(selectedImage!, fit: BoxFit.cover),
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showImagePickerOptions(
                    onImageSelected: (file) {
                      setDialogState(() {
                        selectedImage = file;
                      });
                    },
                  ),
                  icon: const Icon(Icons.image),
                  label: Text(selectedImage != null ? 'Change Image' : 'Add Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  CustomSnackBar.showError(context, 'Please enter brand name');
                  return;
                }
                // Validate: Name must be text (not just numbers)
                if (_isOnlyNumbers(name)) {
                  CustomSnackBar.showError(context, 'Brand name cannot be only numbers. Please enter a text name.');
                  return;
                }
                // Validate: Image is required
                if (selectedImage == null) {
                  CustomSnackBar.showError(context, 'Please upload a brand image');
                  return;
                }
                Navigator.pop(context);
                try {
                  await _addBrand(name, selectedImage);
                } catch (e) {
                  if (mounted) {
                    CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBrandDialog(Map<String, dynamic> brand) {
    final nameController = TextEditingController(text: brand['name'] as String? ?? '');
    File? selectedImage;
    String? existingImageUrl = brand['image'] as String?;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Edit Brand'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  title: 'Brand Name',
                  hintText: 'Enter brand name',
                  controller: nameController,
                  borderColor: _primaryColor,
                ),
                const SizedBox(height: 20),
                if (selectedImage != null || existingImageUrl != null)
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.lightGrey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: selectedImage != null
                          ? Image.file(selectedImage!, fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: existingImageUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showImagePickerOptions(
                    onImageSelected: (file) {
                      setDialogState(() {
                        selectedImage = file;
                      });
                    },
                  ),
                  icon: const Icon(Icons.image),
                  label: Text(selectedImage != null || existingImageUrl != null ? 'Change Image' : 'Add Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  CustomSnackBar.showError(context, 'Please enter brand name');
                  return;
                }
                // Validate: Name must be text (not just numbers)
                if (_isOnlyNumbers(name)) {
                  CustomSnackBar.showError(context, 'Brand name cannot be only numbers. Please enter a text name.');
                  return;
                }
                // Validate: Image is required (either existing or new)
                if (selectedImage == null && (existingImageUrl == null || existingImageUrl.isEmpty)) {
                  CustomSnackBar.showError(context, 'Please upload a brand image');
                  return;
                }
                Navigator.pop(context);
                try {
                  await _updateBrand(
                    brand['id'] as String,
                    name,
                    selectedImage,
                    existingImageUrl,
                  );
                } catch (e) {
                  if (mounted) {
                    CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteBrandDialog(Map<String, dynamic> brand) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Brand'),
        content: Text('Are you sure you want to delete "${brand['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteBrand(
                brand['id'] as String,
                brand['image'] as String?,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ============ DIALOGS FOR TYPES, MODELS, YEARS ============
  void _showAddTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTypeWithCategoryDialog(
        title: 'Add Type',
        hintText: 'Enter new type',
        categories: _allCategories, // Use all categories (not filtered) so sellers can add types to any category
        existingItems: _types.map((e) => e['name'] as String).toList(),
        borderColor: _primaryColor,
        onItemAdded: (type, categoryIds) async {
          try {
            final id = await _service.addType(type, categoryIds: categoryIds);
            if (id != null && mounted) {
              if (categoryIds.length > 1) {
                CustomSnackBar.showSuccess(context, 'Type "$type" was successfully added to ${categoryIds.length} categories.');
              } else {
                CustomSnackBar.showSuccess(context, 'Type added successfully');
              }
              _loadAllData();
              Navigator.pop(context);
            }
          } catch (e) {
            if (mounted) {
              CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
            }
          }
        },
      ),
    );
  }

  void _showEditTypeDialog(Map<String, dynamic> type) {
    final nameController = TextEditingController(text: type['name'] as String? ?? '');
    String? selectedCategoryId = type['category_id'] as String?;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Edit Type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Selection
                Text(
                  'Category',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _primaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: const Text('Select Category'),
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['id'] as String,
                      child: Text(category['name'] as String? ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategoryId = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  title: 'Type Name',
                  hintText: 'Enter type name',
                  controller: nameController,
                  borderColor: _primaryColor,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedCategoryId == null || selectedCategoryId!.isEmpty) {
                  CustomSnackBar.showError(context, 'Please select a category');
                  return;
                }
                if (nameController.text.trim().isEmpty) {
                  CustomSnackBar.showError(context, 'Please enter type name');
                  return;
                }
                Navigator.pop(context);
                await _updateType(
                  type['id'] as String,
                  nameController.text.trim(),
                  selectedCategoryId!,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTypeDialog(Map<String, dynamic> type) {
    _showSimpleDeleteDialog(
      title: 'Delete Type',
      itemName: type['name'] as String? ?? '',
      onDelete: () => _deleteType(type['id'] as String),
    );
  }

  void _showAddModelDialog() {
    final nameController = TextEditingController();
    _showSimpleAddDialog(
      title: 'Add Model',
      controller: nameController,
      hintText: 'Enter model name',
      onAdd: () => _addModel(nameController.text.trim()),
    );
  }

  void _showEditModelDialog(Map<String, dynamic> model) {
    final nameController = TextEditingController(text: model['name'] as String? ?? '');
    _showSimpleEditDialog(
      title: 'Edit Model',
      controller: nameController,
      hintText: 'Enter model name',
      onUpdate: () => _updateModel(model['id'] as String, nameController.text.trim()),
    );
  }

  void _showDeleteModelDialog(Map<String, dynamic> model) {
    _showSimpleDeleteDialog(
      title: 'Delete Model',
      itemName: model['name'] as String? ?? '',
      onDelete: () => _deleteModel(model['id'] as String),
    );
  }


  // ============ HELPER DIALOGS ============
  void _showSimpleAddDialog({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onAdd,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                title: title.split(' ').last,
                hintText: hintText,
                controller: controller,
                borderColor: _primaryColor,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                CustomSnackBar.showError(context, 'Please enter a value');
                return;
              }
              Navigator.pop(context);
              onAdd();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showSimpleEditDialog({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onUpdate,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                title: title.split(' ').last,
                hintText: hintText,
                controller: controller,
                borderColor: _primaryColor,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                CustomSnackBar.showError(context, 'Please enter a value');
                return;
              }
              Navigator.pop(context);
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showSimpleDeleteDialog({
    required String title,
    required String itemName,
    required VoidCallback onDelete,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ============ IMAGE PICKER ============
  void _showImagePickerOptions({required Function(File) onImageSelected}) {
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
                      await _pickImage(ImageSource.camera, onImageSelected);
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
                      await _pickImage(ImageSource.gallery, onImageSelected);
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
            Icon(icon, color: _primaryColor, size: 32),
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

  Future<void> _pickImage(ImageSource source, Function(File) onImageSelected) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        onImageSelected(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error picking image: $e');
      }
    }
  }

  // ============ CRUD OPERATIONS ============
  Future<void> _addCategory(String name, File? imageFile) async {
    try {
      final id = await _service.addCategory(name, imageFile: imageFile);
      if (id != null) {
        CustomSnackBar.showSuccess(context, 'Category added successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to add category');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _updateCategory(String id, String name, File? imageFile, String? existingImageUrl) async {
    try {
      final success = await _service.updateCategory(
        id,
        name,
        imageFile: imageFile,
        existingImageUrl: existingImageUrl,
        isAdmin: widget.isAdmin,
      );
      if (success) {
        CustomSnackBar.showSuccess(context, 'Category updated successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to update category. You may not have permission to edit this item.');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteCategory(String id, String? imageUrl) async {
    try {
      final success = await _service.deleteCategory(
        id,
        imageUrl: imageUrl,
        isAdmin: widget.isAdmin,
      );
      if (success) {
        CustomSnackBar.showSuccess(context, 'Category deleted successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to delete category. You may not have permission to delete this item.');
      }
    } on CategoryInUseException catch (e) {
      CustomSnackBar.showError(context, e.message);
    } catch (e) {
      CustomSnackBar.showError(context, 'Error: $e');
    }
  }

  Future<void> _addBrand(String name, File? imageFile) async {
    try {
      final id = await _service.addBrand(name, imageFile: imageFile);
      if (id != null) {
        CustomSnackBar.showSuccess(context, 'Brand added successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to add brand');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _updateBrand(String id, String name, File? imageFile, String? existingImageUrl) async {
    try {
      final success = await _service.updateBrand(
        id,
        name,
        imageFile: imageFile,
        existingImageUrl: existingImageUrl,
        isAdmin: widget.isAdmin,
      );
      if (success) {
        CustomSnackBar.showSuccess(context, 'Brand updated successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to update brand. You may not have permission to edit this item.');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteBrand(String id, String? imageUrl) async {
    try {
      final success = await _service.deleteBrand(
        id,
        imageUrl: imageUrl,
        isAdmin: widget.isAdmin,
      );
      if (success) {
        CustomSnackBar.showSuccess(context, 'Brand deleted successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to delete brand. You may not have permission to delete this item.');
      }
    } on BrandInUseException catch (e) {
      CustomSnackBar.showError(context, e.message);
    } catch (e) {
      CustomSnackBar.showError(context, 'Error: $e');
    }
  }

  // Helper method to check if string contains only numbers
  bool _isOnlyNumbers(String text) {
    if (text.isEmpty) return false;
    final numericOnly = text.replaceAll(RegExp(r'\s+'), '');
    return numericOnly.isNotEmpty && numericOnly.split('').every((char) => RegExp(r'^\d+$').hasMatch(char));
  }

  Future<void> _updateType(String id, String name, String categoryId) async {
    try {
      // Validate: Name must be text (not just numbers)
      if (_isOnlyNumbers(name.trim())) {
        CustomSnackBar.showError(context, 'Type name cannot be only numbers. Please enter a text name.');
        return;
      }
      final success = await _service.updateType(id, name, isAdmin: widget.isAdmin, categoryId: categoryId);
      if (success) {
        CustomSnackBar.showSuccess(context, 'Type updated successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to update type. You may not have permission to edit this item.');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteType(String id) async {
    try {
      final success = await _service.deleteType(id, isAdmin: widget.isAdmin);
      if (success) {
        CustomSnackBar.showSuccess(context, 'Type deleted successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to delete type. You may not have permission to delete this item.');
      }
    } on TypeInUseException catch (e) {
      CustomSnackBar.showError(context, e.message);
    } catch (e) {
      CustomSnackBar.showError(context, 'Error: $e');
    }
  }

  Future<void> _addModel(String name) async {
    try {
      // Validate: Model name must be an integer
      if (!_isInteger(name.trim())) {
        CustomSnackBar.showError(context, 'Model must be an integer value. Please enter a valid number.');
        return;
      }
      final id = await _service.addModel(name);
      if (id != null) {
        CustomSnackBar.showSuccess(context, 'Model added successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to add model');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _updateModel(String id, String name) async {
    try {
      // Validate: Model name must be an integer
      if (!_isInteger(name.trim())) {
        CustomSnackBar.showError(context, 'Model must be an integer value. Please enter a valid number.');
        return;
      }
      final success = await _service.updateModel(id, name, isAdmin: widget.isAdmin);
      if (success) {
        CustomSnackBar.showSuccess(context, 'Model updated successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to update model. You may not have permission to edit this item.');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteModel(String id) async {
    try {
      final success = await _service.deleteModel(id, isAdmin: widget.isAdmin);
      if (success) {
        CustomSnackBar.showSuccess(context, 'Model deleted successfully');
        _loadAllData();
      } else {
        CustomSnackBar.showError(context, 'Failed to delete model. You may not have permission to delete this item.');
      }
    } on ModelInUseException catch (e) {
      CustomSnackBar.showError(context, e.message);
    } catch (e) {
      CustomSnackBar.showError(context, 'Error: $e');
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

// Dialog for adding type with multiple category selection
class AddTypeWithCategoryDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final List<Map<String, dynamic>> categories;
  final String? initialCategoryId;
  final List<String> existingItems;
  final Future<void> Function(String, List<String>) onItemAdded;
  final Color? borderColor;

  const AddTypeWithCategoryDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.categories,
    this.initialCategoryId,
    required this.existingItems,
    required this.onItemAdded,
    this.borderColor,
  });

  @override
  State<AddTypeWithCategoryDialog> createState() => _AddTypeWithCategoryDialogState();
}

class _AddTypeWithCategoryDialogState extends State<AddTypeWithCategoryDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _hasText = false;
  Set<String> _selectedCategoryIds = {};

  @override
  void initState() {
    super.initState();
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
    final primaryColor = widget.borderColor ?? AppColors.primary;
    
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
                border: Border.all(color: primaryColor),
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
                          activeColor: primaryColor,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _controller,
              hintText: widget.hintText,
              borderColor: primaryColor,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: (_hasText && _selectedCategoryIds.isNotEmpty && !_isLoading) ? _addItem : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: AppColors.lightGrey,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : Text(
                        'Add',
                        style: AppTextStyles.primaryButton.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
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
    // can exist in multiple categories. The service will handle checking
    // which categories already have this type and only add it to new ones.

    setState(() => _isLoading = true);
    
    try {
      await widget.onItemAdded(itemName, _selectedCategoryIds.toList());
      // Dialog will be closed by the onItemAdded callback
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
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
    final numericOnly = text.replaceAll(RegExp(r'\s+'), '');
    return numericOnly.isNotEmpty && numericOnly.split('').every((char) => RegExp(r'^\d+$').hasMatch(char));
  }
}

