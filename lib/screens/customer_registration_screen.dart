import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/cities_data.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/country_code_phone_field.dart';
import '../controller/customer_registration/cubit.dart';
import '../controller/customer_registration/state.dart';
import '../constants/country_dial_codes.dart';
import '../utils/phone_number_utils.dart';
import '../controller/auth_session/cubit.dart';
import 'auth_wrapper.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() => _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState extends State<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _selectedCountry;
  String? _selectedCity;
  String? _profileImagePath;
  String _mobileDialCode = CountryDialCodes.defaultDialCode;
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
        context.read<CustomerRegistrationCubit>().setImagePath(image.path);
      }
    } catch (e) {
      CustomSnackBar.showError(context, 'Error picking image: ${e.toString()}');
    }
  }

  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return false;
    }

    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return false;
    } else if (!_emailController.text.contains('@')) {
      _showError('Please enter a valid email');
      return false;
    }

    final mobileDigits = PhoneNumberUtils.sanitizeNationalNumber(_mobileController.text);
    if (mobileDigits.isEmpty) {
      _showError('Please enter your mobile number');
      return false;
    } else if (!PhoneNumberUtils.isValidNationalNumber(_mobileController.text)) {
      _showError('Phone number must be between 6 and 15 digits');
      return false;
    }

    if (_selectedCountry == null) {
      _showError('Please select your country');
      return false;
    }

    if (_selectedCity == null) {
      _showError('Please select your city');
      return false;
    }

    if (_addressController.text.trim().isEmpty) {
      _showError('Please enter your address');
      return false;
    }

    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return false;
    } else if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }

    if (_confirmPasswordController.text.isEmpty) {
      _showError('Please confirm your password');
      return false;
    } else if (_confirmPasswordController.text != _passwordController.text) {
      _showError('Passwords do not match');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    CustomSnackBar.showError(context, message);
  }

  void _showSuccess(String message) {
    CustomSnackBar.showSuccess(context, message);
  }

  void _register() {
    if (!_validateForm()) return;

    final formattedMobile = PhoneNumberUtils.formatForBackend(_mobileDialCode, _mobileController.text);

    context.read<CustomerRegistrationCubit>().registerCustomer(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      mobile: formattedMobile,
      country: _selectedCountry!,
      city: _selectedCity!,
      address: _addressController.text.trim(),
      password: _passwordController.text,
      profilePicturePath: _profileImagePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: BlocConsumer<CustomerRegistrationCubit, CustomerRegistrationState>(
          listener: (context, state) {
            if (state is CustomerRegistrationSuccess) {
              _showSuccess(state.message);
              // Refresh auth session and move to the post-verification destination
              context.read<AuthSessionCubit>().checkSession();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const AuthWrapper(),
                ),
                (route) => false,
              );
            } else if (state is CustomerRegistrationError) {
              _showError(state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is CustomerRegistrationLoading;
            
            return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // Back Arrow
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Title
                      Text(
                        'Create account',
                        style: AppTextStyles.loginTitle,
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Profile Picture Section
                      Text(
                        'Profile Picture',
                        style: AppTextStyles.roleSelectionDescription,
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Profile Picture Circle
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: _profileImagePath != null
                                  ? ClipOval(
                                      child: Image.file(
                                        File(_profileImagePath!),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const CircleAvatar(
                                      backgroundColor: AppColors.surface,
                                      child: Icon(
                                        Icons.person,
                                        size: 60,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Registration Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Name Field
                            CustomTextField(
                              title: 'Name',
                              hintText: 'Enter your name',
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              borderColor: AppColors.primary,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\'-]")),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Email Field
                            CustomTextField(
                              title: 'Email',
                              hintText: 'Enter your email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              borderColor: AppColors.primary,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Mobile Number Field
                            CountryCodePhoneField(
                              title: 'Mobile Number',
                              hintText: 'Enter your mobile number',
                              controller: _mobileController,
                              selectedDialCode: _mobileDialCode,
                              onDialCodeChanged: (code) {
                                setState(() {
                                  _mobileDialCode = code;
                                });
                              },
                              borderColor: AppColors.primary,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Country Dropdown
                            _buildDropdownField(
                              title: 'Country',
                              value: _selectedCountry,
                              hintText: 'Select country',
                              items: CitiesData.countries,
                              onChanged: (value) {
                                setState(() {
                                  _selectedCountry = value;
                                  _selectedCity = null;
                                  _mobileDialCode = CountryDialCodes.dialCodeForCountry(value);
                                });
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // City Dropdown
                            _buildDropdownField(
                              title: 'City',
                              value: _selectedCity,
                              hintText: _selectedCountry == null
                                  ? 'Select Country First'
                                  : 'Select city',
                              items: _selectedCountry != null
                                  ? CitiesData.getCitiesForCountry(_selectedCountry!)
                                  : [],
                              onChanged: _selectedCountry == null
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedCity = value;
                                      });
                                    },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Address Field
                            CustomTextField(
                              title: 'Address',
                              hintText: 'Enter your address',
                              controller: _addressController,
                              keyboardType: TextInputType.streetAddress,
                              borderColor: AppColors.primary,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Password Field
                            CustomTextField(
                              title: 'Password',
                              hintText: 'Enter your password',
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              borderColor: AppColors.primary,
                              textInputAction: TextInputAction.next,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppColors.textLight,
                                ),
                                onPressed: () {
                                  // Use SchedulerBinding to delay setState and prevent keyboard glitches
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    }
                                  });
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Confirm Password Field
                            CustomTextField(
                              title: 'Confirm Password',
                              hintText: 'Re-enter your password',
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              borderColor: AppColors.primary,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppColors.textLight,
                                ),
                                onPressed: () {
                                  // Use SchedulerBinding to delay setState and prevent keyboard glitches
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                      });
                                    }
                                  });
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Signup Button
                            _buildSignupButton(isLoading),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                );
          },
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hintText,
    required List<String> items,
    required Function(String?)? onChanged,
    String? title,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  hintText,
                  style: AppTextStyles.textFieldHint,
                ),
              ),
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      item,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _register,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: isLoading ? AppColors.grey : AppColors.primary,
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
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Text(
                  'Signup',
                  style: AppTextStyles.primaryButton,
                ),
        ),
      ),
    );
  }
}
