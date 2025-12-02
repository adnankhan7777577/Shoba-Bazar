import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/cities_data.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/country_code_phone_field.dart';
import '../../controller/profile/cubit.dart';
import '../../controller/profile/state.dart';
import '../../controller/profile_edit/cubit.dart';
import '../../controller/profile_edit/state.dart';
import '../../constants/country_dial_codes.dart';
import '../../utils/phone_number_utils.dart';

class SellerEditProfileScreen extends StatefulWidget {
  const SellerEditProfileScreen({super.key});

  @override
  State<SellerEditProfileScreen> createState() => _SellerEditProfileScreenState();
}

class _SellerEditProfileScreenState extends State<SellerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  String? _selectedCountry;
  String? _selectedCity;
  String? _profileImagePath;
  String? _existingProfileImageUrl;
  String _mobileDialCode = CountryDialCodes.defaultDialCode;
  String _whatsappDialCode = CountryDialCodes.defaultDialCode;

  List<String> get _countries => CitiesData.citiesByCountry.keys.toList();
  List<String> get _currentCities => _selectedCountry != null 
      ? CitiesData.citiesByCountry[_selectedCountry] ?? []
      : [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final profileState = context.read<ProfileCubit>().state;
    if (profileState is ProfileLoaded || profileState is ProfileRefreshing) {
      final userData = profileState is ProfileLoaded 
          ? profileState.userData 
          : (profileState as ProfileRefreshing).userData;
      final sellerData = profileState is ProfileLoaded 
          ? profileState.roleSpecificData 
          : (profileState as ProfileRefreshing).roleSpecificData;

      _nameController.text = userData['name'] as String? ?? '';
      _emailController.text = userData['email'] as String? ?? '';
      final phoneParts = PhoneNumberUtils.splitPhoneNumber(userData['mobile'] as String?);
      _mobileDialCode = phoneParts.dialCode;
      _phoneController.text = phoneParts.nationalNumber.isNotEmpty
          ? phoneParts.nationalNumber
          : (userData['mobile'] as String? ?? '');
      _selectedCountry = userData['country'] as String?;
      _selectedCity = userData['city'] as String?;
      final whatsappParts = PhoneNumberUtils.splitPhoneNumber(sellerData?['whatsapp'] as String?);
      _whatsappDialCode = whatsappParts.dialCode;
      _whatsappController.text = whatsappParts.nationalNumber.isNotEmpty
          ? whatsappParts.nationalNumber
          : (sellerData?['whatsapp'] as String? ?? '');
      _shopAddressController.text = sellerData?['shop_address'] as String? ?? '';
      _existingProfileImageUrl = userData['profile_picture_url'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _shopAddressController.dispose();
    super.dispose();
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
        setState(() {
          _profileImagePath = image.path;
        });
        context.read<ProfileEditCubit>().setImagePath(image.path);
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
            Icon(icon, color: AppColors.primary, size: 32),
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

  bool _validateForm() {
    // Validate Name
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return false;
    }

    // Validate Phone Number
    final phoneDigits = PhoneNumberUtils.sanitizeNationalNumber(_phoneController.text);
    if (phoneDigits.isEmpty) {
      _showError('Please enter your phone number');
      return false;
    }
    if (!PhoneNumberUtils.isValidNationalNumber(_phoneController.text)) {
      _showError('Phone number must be between 6 and 15 digits');
      return false;
    }

    // Validate WhatsApp Number
    final whatsappDigits = PhoneNumberUtils.sanitizeNationalNumber(_whatsappController.text);
    if (whatsappDigits.isEmpty) {
      _showError('Please enter your WhatsApp number');
      return false;
    }
    if (!PhoneNumberUtils.isValidNationalNumber(_whatsappController.text)) {
      _showError('WhatsApp number must be between 6 and 15 digits');
      return false;
    }

    // Validate Country
    if (_selectedCountry == null || _selectedCountry!.isEmpty) {
      _showError('Please select your country');
      return false;
    }

    // Validate City
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showError('Please select your city');
      return false;
    }

    // Validate Shop Address
    if (_shopAddressController.text.trim().isEmpty) {
      _showError('Please enter your shop address');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<ProfileEditCubit, ProfileEditState>(
          listener: (context, state) {
            if (state is ProfileEditSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.success,
                ),
              );
              // Refresh profile data
              context.read<ProfileCubit>().fetchProfile();
              Navigator.pop(context);
            } else if (state is ProfileEditError) {
              _showError(state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is ProfileEditLoading;
            
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildProfilePictureSection(),
                          const SizedBox(height: 30),
                          CustomTextField(
                            title: 'Name',
                            hintText: 'Enter your name',
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\'-]")),
                            ],
                            borderColor: AppColors.primary,
                          ),
                          const SizedBox(height: 20),
                          // Email field (read-only, cannot be changed)
                          IgnorePointer(
                            child: Opacity(
                              opacity: 0.6,
                              child: CustomTextField(
                                title: 'Email',
                                hintText: 'Enter your email',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                borderColor: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          CountryCodePhoneField(
                            title: 'Phone Number',
                            hintText: 'Enter your phone number',
                            controller: _phoneController,
                            selectedDialCode: _mobileDialCode,
                            onDialCodeChanged: (code) {
                              setState(() {
                                _mobileDialCode = code;
                              });
                            },
                            borderColor: AppColors.primary,
                          ),
                          const SizedBox(height: 20),
                          CountryCodePhoneField(
                            title: 'WhatsApp Number',
                            hintText: 'Enter your WhatsApp number',
                            controller: _whatsappController,
                            selectedDialCode: _whatsappDialCode,
                            onDialCodeChanged: (code) {
                              setState(() {
                                _whatsappDialCode = code;
                              });
                            },
                            borderColor: AppColors.primary,
                          ),
                          const SizedBox(height: 20),
                          CustomDropdown(
                            title: 'Country',
                            value: _selectedCountry,
                            hintText: 'Select country',
                            items: _countries,
                            borderColor: AppColors.primary,
                            onChanged: (value) {
                              setState(() {
                                _selectedCountry = value;
                                _selectedCity = null;
                                final dial = CountryDialCodes.dialCodeForCountry(value);
                                _mobileDialCode = dial;
                                _whatsappDialCode = dial;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          CustomDropdown(
                            title: 'City',
                            value: _selectedCity,
                            hintText: _selectedCountry == null 
                                ? 'Select Country First' 
                                : 'Select city',
                            items: _currentCities,
                            borderColor: AppColors.primary,
                            onChanged: _selectedCountry == null 
                                ? (_) {} 
                                : (value) {
                                    setState(() {
                                      _selectedCity = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 20),
                          CustomTextField(
                            title: 'Shop Address',
                            hintText: 'Enter your shop address',
                            controller: _shopAddressController,
                            keyboardType: TextInputType.streetAddress,
                            borderColor: AppColors.primary,
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: AppButton.primary(
                              text: 'Update',
                              onPressed: isLoading ? null : _handleSaveProfile,
                              isLoading: isLoading,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Change Details',
              style: AppTextStyles.heading2.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Picture',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 3),
                ),
                child: ClipOval(
                  child: _profileImagePath != null
                      ? Image.file(
                          File(_profileImagePath!),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        )
                      : _existingProfileImageUrl != null && _existingProfileImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _existingProfileImageUrl!,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                              placeholder: (context, url) => Container(
                                color: AppColors.white,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleSaveProfile() {
    if (!_validateForm()) return;

    final profileState = context.read<ProfileCubit>().state;
    if (profileState is ProfileLoaded || profileState is ProfileRefreshing) {
      final userData = profileState is ProfileLoaded 
          ? profileState.userData 
          : (profileState as ProfileRefreshing).userData;
      final userId = userData['id'].toString();

      final formattedMobile = PhoneNumberUtils.formatForBackend(_mobileDialCode, _phoneController.text);
      final formattedWhatsapp = PhoneNumberUtils.formatForBackend(_whatsappDialCode, _whatsappController.text);

      context.read<ProfileEditCubit>().updateSellerProfile(
        userId: userId,
        name: _nameController.text.trim(),
        mobile: formattedMobile,
        whatsapp: formattedWhatsapp,
        country: _selectedCountry!,
        city: _selectedCity!,
        shopAddress: _shopAddressController.text.trim(),
        profilePicturePath: _profileImagePath,
      );
    }
  }
}
