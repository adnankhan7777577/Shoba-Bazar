import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/banner_service.dart';
import '../../widgets/custom_snackbar.dart';

class AdminAddEditBannerScreen extends StatefulWidget {
  final Map<String, dynamic>? banner;

  const AdminAddEditBannerScreen({
    super.key,
    this.banner,
  });

  @override
  State<AdminAddEditBannerScreen> createState() => _AdminAddEditBannerScreenState();
}

class _AdminAddEditBannerScreenState extends State<AdminAddEditBannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final BannerService _service = BannerService();
  
  File? _bannerImage;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.banner != null;
    if (_isEditMode && widget.banner != null) {
      _textController.text = widget.banner!['text'] as String? ?? '';
      _existingImageUrl = widget.banner!['image_url'] as String?;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _bannerImage = File(image.path);
          _existingImageUrl = null; // Clear existing URL when new image is selected
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error picking image: ${e.toString()}');
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _bannerImage = File(image.path);
          _existingImageUrl = null; // Clear existing URL when new image is selected
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error taking photo: ${e.toString()}');
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_bannerImage == null && _existingImageUrl == null) {
      CustomSnackBar.showError(context, 'Please select a banner image');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final adminUserId = await _service.getAdminUserId();
      if (adminUserId == null) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Admin user not found');
        }
        return;
      }

      String? imageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_bannerImage != null) {
        final uploadedUrl = await _service.uploadBannerImage(_bannerImage!);
        if (uploadedUrl == null) {
          if (mounted) {
            CustomSnackBar.showError(context, 'Failed to upload image');
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
        imageUrl = uploadedUrl;
      }

      if (imageUrl == null) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Image URL is required');
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      if (_isEditMode && widget.banner != null) {
        // Update existing banner
        final bannerId = widget.banner!['id'] as String;
        final result = await _service.updateBanner(
          bannerId: bannerId,
          imageUrl: imageUrl,
          text: _textController.text.trim(),
        );

        if (result != null && mounted) {
          CustomSnackBar.showSuccess(context, 'Banner updated successfully');
          Navigator.pop(context, true);
        } else {
          if (mounted) {
            CustomSnackBar.showError(context, 'Failed to update banner');
          }
        }
      } else {
        // Create new banner
        final result = await _service.createBanner(
          imageUrl: imageUrl,
          text: _textController.text.trim(),
          userId: adminUserId,
        );

        if (result != null && mounted) {
          CustomSnackBar.showSuccess(context, 'Banner created successfully');
          Navigator.pop(context, true);
        } else {
          if (mounted) {
            CustomSnackBar.showError(context, 'Failed to create banner');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Banner' : 'Add Banner'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: AppColors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Image Section
              _buildImageSection(),
              
              const SizedBox(height: 24),
              
              // Banner Text Section
              _buildTextSection(),
              
              const SizedBox(height: 32),
              
              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Banner Image',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.adminPrimary,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: _bannerImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _bannerImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _existingImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      )
                    : _buildPlaceholder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to select image from gallery or camera',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Add Banner Image',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Banner Text',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.adminPrimary,
              width: 1.5,
            ),
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
            controller: _textController,
            maxLines: 3,
            style: AppTextStyles.bodyMedium,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter banner text';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Enter banner text',
              hintStyle: AppTextStyles.textFieldHint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: AppColors.white,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimaryLight),
                ),
              )
            : Text(
                _isEditMode ? 'Update Banner' : 'Create Banner',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

