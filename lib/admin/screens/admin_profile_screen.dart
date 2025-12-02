import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/password_change_dialog.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/country_code_phone_field.dart';
import '../../controller/profile/cubit.dart';
import '../../controller/profile/state.dart';
import '../../controller/profile_edit/cubit.dart';
import '../../controller/profile_edit/state.dart';
import '../../controller/logout/cubit.dart';
import '../../controller/logout/state.dart';
import '../../utils/phone_number_utils.dart';
import '../../screens/auth_wrapper.dart';
import '../../customer/screens/customer_dashboard_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  File? _avatarFile;
  String? _selectedImagePath;
  final GlobalKey<FormState> _editFormKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Fetch profile when screen loads
    context.read<ProfileCubit>().fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            // Don't show error if we're logging out or user is not logged in
            if (state is ProfileError) {
              // Check if user is still logged in before showing error
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null && state.message != 'User not logged in') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          builder: (context, profileState) {
            return BlocConsumer<ProfileEditCubit, ProfileEditState>(
              listener: (context, editState) {
                if (editState is ProfileEditSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(editState.message),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  // Refresh profile after update
                  context.read<ProfileCubit>().fetchProfile();
                  // Clear selected image
                  setState(() {
                    _avatarFile = null;
                    _selectedImagePath = null;
                  });
                  Navigator.pop(context); // Close edit dialog if open
                } else if (editState is ProfileEditError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(editState.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              builder: (context, editState) {
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
                    final isSaving = editState is ProfileEditLoading;
                    final isLoggingOut = logoutState is LogoutLoading;

                    // If logging out, show loading indicator
                    if (isLoggingOut) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                        ),
                      );
                    }

                    // Show loader only if no cached data exists and not logging out
                    if (isLoading && !isRefreshing) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                        ),
                      );
                    }

                    // Get user data
                    Map<String, dynamic> userData;
                    if (profileState is ProfileRefreshing) {
                      userData = profileState.userData;
                    } else if (profileState is ProfileLoaded) {
                      userData = profileState.userData;
                    } else if (profileState is ProfileError) {
                      // Check if user is still logged in
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user == null) {
                        // User logged out, show loading (will navigate away soon)
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                          ),
                        );
                      }
                      // Show error only if user is still logged in
                      return Center(
                        child: Text(
                          'Failed to load profile',
                          style: AppTextStyles.bodyMedium,
                        ),
                      );
                    } else {
                      // ProfileInitial or other states - show loading
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                        ),
                      );
                    }

                    // Extract admin profile data (with defaults for empty values)
                    final adminName = userData['name'] as String? ?? 'Admin User';
                    final email = Supabase.instance.client.auth.currentUser?.email ?? 
                                  userData['email'] as String? ?? 'No email';
                    final phone = userData['mobile'] as String? ?? 'Not set';
                    // Safely get profile picture URL - field may not exist in DB
                    final profilePictureUrl = userData.containsKey('profile_picture_url') 
                        ? userData['profile_picture_url'] as String? 
                        : null;

                    return Stack(
                      children: [
                        Column(
                          children: [
                            // Header Section with Profile Info
                            _buildProfileHeader(
                              adminName: adminName,
                              profilePictureUrl: profilePictureUrl,
                              isUpdatingImage: isSaving,
                            ),
                            
                            // Main Content
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    
                                    // User Information Section
                                    _buildUserInfoSection(
                                      adminName: adminName,
                                      email: email,
                                      phone: phone,
                                    ),
                                    
                                    const SizedBox(height: 30),
                                    
                                    // Change Password Button
                                    _buildChangePasswordButton(),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // View Customer Home Button
                                    _buildViewCustomerHomeButton(),
                                    
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
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                              ),
                            ),
                          ),
                        // Loading overlay when saving
                        if (isSaving)
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
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

  Widget _buildProfileHeader({
    required String adminName,
    String? profilePictureUrl,
    required bool isUpdatingImage,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Header Row with Back Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
                
                // Admin Title
                Expanded(
                  child: Text(
                    'Admin Profile',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Edit/Profile update icon
                GestureDetector(
                  onTap: _showEditProfileDialog,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
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
          
          // Profile Picture with change action
          Stack(
            alignment: Alignment.bottomRight,
            children: [
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
                  child: _avatarFile != null
                      ? Image.file(
                          _avatarFile!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      : profilePictureUrl != null && profilePictureUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profilePictureUrl,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.white,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.white,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.admin_panel_settings,
                                      color: AppColors.adminPrimary,
                                      size: 40,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        color: AppColors.adminPrimary,
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
                                children: const [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: AppColors.adminPrimary,
                                    size: 40,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      color: AppColors.adminPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'SHOBA BAZAR',
                                    style: TextStyle(
                                      color: AppColors.adminPrimary,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
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
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                      ),
                    ),
                  ),
                ),
              
              GestureDetector(
                onTap: isUpdatingImage ? null : _changeProfilePhoto,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.adminPrimary,
                    shape: BoxShape.circle,
                    boxShadow: isUpdatingImage ? [] : null,
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: isUpdatingImage ? Colors.white70 : Colors.white,
                    size: 18,
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

  Widget _buildUserInfoSection({
    required String adminName,
    required String email,
    required String phone,
  }) {
    // Get country from userData
    final profileState = context.read<ProfileCubit>().state;
    Map<String, dynamic>? userData;
    if (profileState is ProfileLoaded) {
      userData = profileState.userData;
    } else if (profileState is ProfileRefreshing) {
      userData = profileState.userData;
    }
    final country = userData?['country'] as String? ?? '';

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
          // Name Row
          _buildInfoRow(
            icon: Icons.person_outline,
            text: adminName,
          ),
          
          const SizedBox(height: 20),
          
          // Email Row
          _buildInfoRow(
            icon: Icons.email_outlined,
            text: email,
          ),
          
          const SizedBox(height: 20),
          
          // Phone Row
          _buildInfoRow(
            icon: Icons.phone_outlined,
            text: phone,
          ),
          
          const SizedBox(height: 20),
          
          // Country Row
          if (country.isNotEmpty)
            _buildInfoRow(
              icon: Icons.public_outlined,
              text: country,
            ),
          
          if (country.isNotEmpty) const SizedBox(height: 20),

          // Role Row - Management
          _buildInfoRow(
            icon: Icons.business,
            text: 'Management',
          ),
          
          const SizedBox(height: 20),
          
          // Admin Role
          _buildInfoRow(
            icon: Icons.admin_panel_settings,
            text: 'Admin',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    Color? iconColor,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.adminPrimary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppColors.adminPrimary,
            size: 20,
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
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
            color: AppColors.adminPrimary,
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
              color: AppColors.adminPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewCustomerHomeButton() {
    return Center(
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.adminPrimary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.adminPrimary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomerDashboardScreen(showBackButton: true),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.adminPrimary,
            foregroundColor: AppColors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.home, size: 20),
          label: Text(
            'View Customer Home',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isLoggingOut) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.adminPrimary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoggingOut ? null : () {
          _showLogoutConfirmationDialog();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: AppColors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoggingOut
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimaryLight),
                ),
              )
            : Text(
                'Logout',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
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
          style: AppTextStyles.heading3.copyWith(
            color: AppColors.adminPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<LogoutCubit>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.adminPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Logout',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
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
      builder: (context) => const PasswordChangeDialog(isAdmin: true),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _avatarFile = File(image.path);
          _selectedImagePath = image.path;
        });
        
        // Get current profile data and immediately update backend
        final profileState = context.read<ProfileCubit>().state;
        if (profileState is ProfileLoaded || profileState is ProfileRefreshing) {
          final userData = profileState is ProfileLoaded 
              ? profileState.userData 
              : (profileState as ProfileRefreshing).userData;
          final userId = userData['id'].toString();
          
          // Update profile with new image immediately (skip validations for image-only update)
          context.read<ProfileEditCubit>().updateAdminProfile(
            userId: userId,
            name: userData['name'] as String? ?? '',
            mobile: userData['mobile'] as String? ?? '',
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
            Icon(icon, color: AppColors.adminPrimary, size: 32),
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

  Future<void> _changeProfilePhoto() async {
    _showImagePickerOptions();
  }

  void _showImagePickerOptionsForDialog() {
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

  void _showEditProfileDialog() {
    final profileState = context.read<ProfileCubit>().state;
    Map<String, dynamic>? userData;
    
    if (profileState is ProfileLoaded) {
      userData = profileState.userData;
    } else if (profileState is ProfileRefreshing) {
      userData = profileState.userData;
    }

    if (userData == null) {
      CustomSnackBar.showError(context, 'Profile data not available');
      return;
    }

    final nameController = TextEditingController(
      text: userData['name'] as String? ?? '',
    );
    final phoneParts = PhoneNumberUtils.splitPhoneNumber(userData['mobile'] as String?);
    String selectedDialCode = phoneParts.dialCode;
    final phoneController = TextEditingController(
      text: phoneParts.nationalNumber.isNotEmpty
          ? phoneParts.nationalNumber
          : PhoneNumberUtils.sanitizeNationalNumber(userData['mobile'] as String? ?? ''),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Update Profile',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.adminPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(controller: nameController, label: 'Name'),
                    const SizedBox(height: 12),
                    CountryCodePhoneField(
                      title: 'Mobile Number',
                      hintText: 'Enter your mobile number',
                      controller: phoneController,
                      selectedDialCode: selectedDialCode,
                      onDialCodeChanged: (code) {
                        setDialogState(() {
                          selectedDialCode = code;
                        });
                      },
                      borderColor: AppColors.adminPrimary,
                    ),
                    const SizedBox(height: 20),
                    // Image Upload Section
                    _buildImageUploadSection(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_editFormKey.currentState?.validate() ?? false) {
                    if (!PhoneNumberUtils.isValidNationalNumber(phoneController.text)) {
                      CustomSnackBar.showError(context, 'Please enter a valid phone number (6-15 digits)');
                      return;
                    }
                    final userId = userData!['id'].toString();
                    final formattedMobile = PhoneNumberUtils.formatForBackend(
                      selectedDialCode,
                      phoneController.text,
                    );
                    context.read<ProfileEditCubit>().updateAdminProfile(
                      userId: userId,
                      name: nameController.text.trim(),
                      mobile: formattedMobile,
                      profilePicturePath: _selectedImagePath,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary),
                child: Text(
                  'Update',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Picture',
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            _showImagePickerOptionsForDialog();
          },
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.adminPrimary,
                width: 1.5,
              ),
            ),
            child: _avatarFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _avatarFile!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        color: AppColors.adminPrimary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload image',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.adminPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: (label.toLowerCase().contains('mobile') || label.toLowerCase().contains('phone')) ? 11 : null,
          inputFormatters: (label.toLowerCase().contains('mobile') || label.toLowerCase().contains('phone'))
              ? [FilteringTextInputFormatter.digitsOnly]
              : (label.toLowerCase().contains('name'))
                  ? [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\'-]"))]
                  : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            counterText: '', // Hide the character counter
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter $label';
            }
            // Validate phone number length if it's a phone field
            if (label.toLowerCase().contains('mobile') || label.toLowerCase().contains('phone')) {
              if (value.trim().length != 11) {
                return 'Phone number must be exactly 11 digits';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

}
