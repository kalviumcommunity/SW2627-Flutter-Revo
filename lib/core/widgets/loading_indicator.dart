import 'package:flutter/material.dart';
import '../constants/revo_colors.dart';

/// Standard Revo Loading Indicator widget.
/// Supports both compact in-button spinners and full-screen loading states.
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? message;

  const AppLoadingIndicator({
    super.key,
    this.size = 28.0,
    this.strokeWidth = 2.5,
    this.color,
    this.message,
  });

  /// Factory for compact loading states inside buttons and chips
  const AppLoadingIndicator.small({
    super.key,
    this.size = 18.0,
    this.strokeWidth = 2.0,
    this.color = Colors.white,
    this.message,
  });

  /// Factory for full-screen loading states with optional message
  const AppLoadingIndicator.fullScreen({
    super.key,
    this.size = 36.0,
    this.strokeWidth = 3.0,
    this.color = RevoColors.primary,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    if (message != null && message!.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinner,
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: RevoColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Center(child: spinner);
  }
}
