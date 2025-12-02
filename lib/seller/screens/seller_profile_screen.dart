import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/password_change_dialog.dart';
import '../../widgets/custom_snackbar.dart';
import '../../controller/profile/cubit.dart';
import '../../controller/profile/state.dart';
import '../../controller/logout/cubit.dart';
import '../../controller/logout/state.dart';
import '../../controller/profile_edit/cubit.dart';
import '../../controller/profile_edit/state.dart';
import '../../screens/auth_wrapper.dart';
import '../../screens/product_metadata_management_screen.dart';
import 'seller_edit_profile_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Fetch profile when screen loads (will show cached data if available)
    context.read<ProfileCubit>().fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<ProfileEditCubit, ProfileEditState>(
          listener: (context, editState) {
            if (editState is ProfileEditSuccess) {
              CustomSnackBar.showSuccess(context, editState.message);
              // Refresh profile to show updated image
              context.read<ProfileCubit>().fetchProfile();
            } else if (editState is ProfileEditError) {
              CustomSnackBar.showError(context, editState.message);
            }
          },
          builder: (context, editState) {
            return BlocConsumer<ProfileCubit, ProfileState>(
              listener: (context, state) {
                if (state is ProfileError) {
                  CustomSnackBar.showError(context, state.message);
                }
              },
              builder: (context, profileState) {
                return BlocConsumer<LogoutCubit, LogoutState>(
              listener: (context, logoutState) {
                if (logoutState is LogoutSuccess) {
                  // Navigate to AuthWrapper and clear all routes
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const AuthWrapper(),
                    ),
                    (route) => false, // Remove all previous routes
                  );
                } else if (logoutState is LogoutError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(logoutState.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              builder: (context, logoutState) {
                final isLoading = profileState is ProfileLoading;
                final isRefreshing = profileState is ProfileRefreshing;
                final isLoggingOut = logoutState is LogoutLoading;

                // Show loader only if no cached data exists
                if (isLoading && !isRefreshing) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // Use cached data if refreshing, or loaded data
                Map<String, dynamic> userData;
                Map<String, dynamic>? sellerData;

                if (profileState is ProfileRefreshing) {
                  userData = profileState.userData;
                  sellerData = profileState.roleSpecificData;
                } else if (profileState is ProfileLoaded) {
                  userData = profileState.userData;
                  sellerData = profileState.roleSpecificData;
                } else {
                  return Center(
                    child: Text(
                      'Failed to load profile',
                      style: AppTextStyles.bodyMedium,
                    ),
                  );
                }
                
                final isUpdatingImage = editState is ProfileEditLoading;
                
                return Stack(
                  children: [
                    Column(
                      children: [
                        // Header Section with Profile Info
                        _buildProfileHeader(userData, isUpdatingImage),
                        
                        // Main Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                
                                // User Information Section
                                _buildUserInfoSection(userData, sellerData),
                                
                                const SizedBox(height: 30),
                                
                                // Change Password Button
                                _buildChangePasswordButton(),
                                
                                const SizedBox(height: 16),
                                
                                // Manage Data Button
                                _buildManageDataButton(),
                                
                                const SizedBox(height: 16),
                                
                                // Logout Button
                                _buildLogoutButton(isLoggingOut),
                                
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Subtle refresh indicator at top (only when refreshing)
                    if (isRefreshing)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, bool isUpdatingImage) {
    final name = userData['name'] as String? ?? 'Seller';
    final profilePictureUrl = userData['profile_picture_url'] as String?;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Header Row with Edit Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                
                // Seller Name
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Edit Button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SellerEditProfileScreen(),
                      ),
                    ).then((_) {
                      // Refresh profile after editing
                      context.read<ProfileCubit>().fetchProfile();
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Profile Picture with Camera Icon
          Stack(
            children: [
              // Profile Picture
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: profilePictureUrl,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          placeholder: (context, url) => Container(
                            color: AppColors.white,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.white,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.build,
                                  color: AppColors.primary,
                                  size: 40,
                                ),
                                Text(
                                  'SELLER',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.white,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.build,
                                color: AppColors.primary,
                                size: 40,
                              ),
                              Text(
                                'SELLER',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              
              // Loading Overlay
              if (isUpdatingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    ),
                  ),
                ),
              
              // Camera Icon Button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isUpdatingImage ? null : () {
                    _showImagePickerOptions();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: isUpdatingImage ? [] : null,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: isUpdatingImage ? AppColors.textLight : AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(
    Map<String, dynamic> userData,
    Map<String, dynamic>? sellerData,
  ) {
    final email = userData['email'] as String? ?? '';
    final mobile = userData['mobile'] as String? ?? '';
    final city = userData['city'] as String? ?? '';
    final country = userData['country'] as String?;
    final shopAddress = sellerData?['shop_address'] as String? ?? '';
    final whatsapp = sellerData?['whatsapp'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Email Row
          _buildInfoRow(
            icon: Icons.email_outlined,
            text: email,
          ),
          
          const SizedBox(height: 20),
          
          // Phone Row
          _buildInfoRow(
            icon: Icons.phone_outlined,
            text: mobile,
          ),
          
          const SizedBox(height: 20),
          
          // City Row
          _buildInfoRow(
            icon: Icons.location_city_outlined,
            text: city,
          ),
          
          const SizedBox(height: 20),
          
          // Country Row
          _buildInfoRow(
            icon: Icons.public_outlined,
            text: country ?? '',
          ),
          
          const SizedBox(height: 20),
          
          // Shop Address Row
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            text: shopAddress,
          ),
          
          const SizedBox(height: 20),
          
          // WhatsApp Row
          _buildInfoRow(
            text: whatsapp,
            imagePath: 'assets/images/whatsapp.png',
            onTap: whatsapp.isNotEmpty ? () => _openWhatsApp(whatsapp) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    IconData? icon,
    required String text,
    Color? iconColor,
    String? imagePath,
    VoidCallback? onTap,
  }) {
    final rowWidget = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: imagePath != null
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    imagePath,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                )
              : Icon(
                  icon ?? Icons.info,
                  color: iconColor ?? AppColors.primary,
                  size: 20,
                ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Text(
            text.isEmpty ? 'Not provided' : text,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: onTap != null ? AppColors.primary : null,
            ),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: rowWidget,
        ),
      );
    }

    return rowWidget;
  }

  Future<void> _openWhatsApp(String rawNumber) async {
    if (rawNumber.isEmpty) return;
    
    // Clean the number: remove all non-numeric characters except +
    final number = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid WhatsApp number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Create default message for seller profile WhatsApp
    const defaultMessage = 'Hello! I am contacting you from Shoba Bazar app.';
    
    // URL encode the message
    final encodedMessage = Uri.encodeComponent(defaultMessage);
    final uri = Uri.parse('https://wa.me/$number?text=$encodedMessage');
    
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open WhatsApp'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildChangePasswordButton() {
    return Center(
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.textPrimary,
            width: 1,
          ),
        ),
        child: TextButton(
          onPressed: () {
            _showChangePasswordDialog();
          },
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Change Password',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManageDataButton() {
    return Center(
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.textPrimary,
            width: 1,
          ),
        ),
        child: TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProductMetadataManagementScreen(isAdmin: false),
              ),
            );
          },
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Manage Product Data',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        // Get current profile data
        final profileState = context.read<ProfileCubit>().state;
        if (profileState is ProfileLoaded || profileState is ProfileRefreshing) {
          final userData = profileState is ProfileLoaded 
              ? profileState.userData 
              : (profileState as ProfileRefreshing).userData;
          final sellerData = profileState is ProfileLoaded 
              ? profileState.roleSpecificData 
              : (profileState as ProfileRefreshing).roleSpecificData;
          final userId = userData['id'].toString();
          
          // Update profile with new image immediately (skip validations for image-only update)
          context.read<ProfileEditCubit>().updateSellerProfile(
            userId: userId,
            name: userData['name'] as String? ?? '',
            mobile: userData['mobile'] as String? ?? '',
            whatsapp: sellerData?['whatsapp'] as String? ?? '',
            country: userData['country'] as String? ?? '',
            city: userData['city'] as String? ?? '',
            shopAddress: sellerData?['shop_address'] as String? ?? '',
            profilePicturePath: image.path,
            skipValidations: true, // Skip validations when only updating image
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error picking image: ${e.toString()}');
      }
    }
  }

  void _showImagePickerOptions() {
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
              'Change Profile Picture',
              style: AppTextStyles.heading3,
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: _buildImagePickerOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: _buildImagePickerOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
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

  Widget _buildImagePickerOption({
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

  Widget _buildLogoutButton(bool isLoggingOut) {
    return GestureDetector(
      onTap: isLoggingOut ? null : () => _showLogoutConfirmationDialog(),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: isLoggingOut ? AppColors.grey : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoggingOut
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Text(
                  'Logout',
                  style: AppTextStyles.primaryButton,
                ),
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Logout',
          style: AppTextStyles.heading3,
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<LogoutCubit>().logout();
            },
            child: Text(
              'Logout',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const PasswordChangeDialog(),
    );
  }
}
