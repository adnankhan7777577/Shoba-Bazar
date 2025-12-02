import 'package:flutter/material.dart';
import '../constants/button_styles.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final ButtonSize size;
  final ButtonType type;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.size = ButtonSize.large,
    this.type = ButtonType.primary,
  });

  @override
  Widget build(BuildContext context) {
    ButtonStyle buttonStyle = _getButtonStyle();
    Widget buttonChild = _getButtonChild();

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: _buildButton(buttonStyle, buttonChild),
      );
    }

    return _buildButton(buttonStyle, buttonChild);
  }

  Widget _buildButton(ButtonStyle style, Widget child) {
    switch (type) {
      case ButtonType.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: child,
        );  
      case ButtonType.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: child,
        );
      case ButtonType.success:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: child,
        );
      case ButtonType.error:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: child,
        );
    }
  }

  ButtonStyle _getButtonStyle() {
    switch (type) {
      case ButtonType.primary:
        return size == ButtonSize.small ? ButtonStyles.primarySmall : ButtonStyles.primary;
      case ButtonType.secondary:
        return size == ButtonSize.small ? ButtonStyles.secondarySmall : ButtonStyles.secondary;
      case ButtonType.success:
        return ButtonStyles.success;
      case ButtonType.error:
        return ButtonStyles.error;
    }
  }

  Widget _getButtonChild() {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Text(text);
  }
}

enum ButtonSize { small, large }

enum ButtonType { primary, secondary, success, error }

// Convenience constructors for common button types
class AppButton {
  static PrimaryButton primary({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    ButtonSize size = ButtonSize.large,
  }) {
    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      size: size,
      type: ButtonType.primary,
    );
  }

  static PrimaryButton secondary({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    ButtonSize size = ButtonSize.large,
  }) {
    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      size: size,
      type: ButtonType.secondary,
    );
  }

  static PrimaryButton success({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    ButtonSize size = ButtonSize.large,
  }) {
    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      size: size,
      type: ButtonType.success,
    );
  }

  static PrimaryButton error({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    ButtonSize size = ButtonSize.large,
  }) {
    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      size: size,
      type: ButtonType.error,
    );
  }
}
