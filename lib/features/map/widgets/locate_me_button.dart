import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// LocateMeButton - Floating GPS button to center map on user location
/// ---------------------------------------------------------------------------
/// A circular 44x44 floating action button with Cupertino styling that
/// centers the map on the user's GPS position when tapped.
///
/// Design:
/// - 44x44 circular button (Apple's minimum recommended tap target size)
/// - Semi-transparent background with backdrop blur (frosted glass effect)
/// - CupertinoIcons.location_fill icon in iOS blue (#007AFF)
/// - Positioned in the bottom-right corner of the map (by the parent)
///
/// Interaction:
/// - On tap: the parent (MapScreen) reads [currentLocationProvider] and
///   calls [mapControllerProvider.notifier.centerOnUser()] to animate
///   the map to the user's position at zoom level 15 (street-level)
///
/// This is a plain [StatelessWidget] because:
/// - It has no internal state or animations
/// - The tap callback is provided by the parent via [onPressed]
/// - Provider access is handled by the parent MapScreen
/// ---------------------------------------------------------------------------
class LocateMeButton extends StatelessWidget {
  /// Callback invoked when the button is tapped.
  /// The parent is responsible for reading the location provider and
  /// animating the map controller to the user's position.
  final VoidCallback onPressed;

  const LocateMeButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface;

    return ClipOval(
      // ClipOval ensures the backdrop blur is circular (matching the button shape)
      child: BackdropFilter(
        // --- Frosted glass blur effect ---
        // Blurs the map content behind the button, creating the
        // iOS-standard frosted glass appearance.
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),

        child: SizedBox(
          // 44x44 matches Apple's Human Interface Guidelines for
          // minimum interactive element size, ensuring easy tap targets.
          width: 44,
          height: 44,

          child: CupertinoButton(
            padding: EdgeInsets.zero,
            // Semi-transparent background over the blurred map content.
            // Using 70% opacity for readable button appearance.
            color: backgroundColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(22),
            onPressed: onPressed,

            child: Icon(
              // Filled location arrow icon -- the standard iOS "locate me" icon
              CupertinoIcons.location_fill,
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF80BFFF)
                  : CupertinoColors.activeBlue,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
