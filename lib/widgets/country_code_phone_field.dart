import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/country_dial_codes.dart';

class CountryCodePhoneField extends StatefulWidget {
  final String title;
  final String hintText;
  final TextEditingController controller;
  final String selectedDialCode;
  final ValueChanged<String> onDialCodeChanged;
  final Color? borderColor;
  final bool enabled;

  const CountryCodePhoneField({
    super.key,
    required this.title,
    required this.hintText,
    required this.controller,
    required this.selectedDialCode,
    required this.onDialCodeChanged,
    this.borderColor,
    this.enabled = true,
  });

  @override
  State<CountryCodePhoneField> createState() => _CountryCodePhoneFieldState();
}

class _CountryCodePhoneFieldState extends State<CountryCodePhoneField> {
  int _getMaxLength() {
    final length = CountryDialCodes.getPhoneNumberLength(widget.selectedDialCode);
    return length ?? 15; // Default to 15 if country not found
  }

  @override
  void didUpdateWidget(CountryCodePhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When dial code changes, trim the phone number if it exceeds the new max length
    if (oldWidget.selectedDialCode != widget.selectedDialCode) {
      final newMaxLength = _getMaxLength();
      final currentText = widget.controller.text;
      if (currentText.length > newMaxLength) {
        widget.controller.text = currentText.substring(0, newMaxLength);
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: newMaxLength),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxLength = _getMaxLength();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.borderColor ?? AppColors.primary,
              width: 1.5,
            ),
            color: widget.enabled ? AppColors.surface : AppColors.lightGrey.withOpacity(0.3),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.enabled ? () => _showCountryCodeSheet(context) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.selectedDialCode,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: AppColors.lightGrey.withOpacity(0.5),
              ),
              Expanded(
                child: TextField(
                  key: ValueKey('phone_field_${widget.selectedDialCode}_$maxLength'),
                  controller: widget.controller,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: AppTextStyles.textFieldHint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCountryCodeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: CountryDialCodes.dialCodes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final info = CountryDialCodes.dialCodes[index];
              return ListTile(
                title: Text('${info.country} (${info.dialCode})'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDialCodeChanged(info.dialCode);
                  // Clear the field when country changes to enforce new length
                  final currentText = widget.controller.text;
                  final newMaxLength = CountryDialCodes.getPhoneNumberLength(info.dialCode) ?? 15;
                  if (currentText.length > newMaxLength) {
                    widget.controller.text = currentText.substring(0, newMaxLength);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

