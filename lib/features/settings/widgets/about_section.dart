import 'package:flutter/material.dart';

import 'package:bussin/core/constants/app_constants.dart';

/// ---------------------------------------------------------------------------
/// AboutSection - App information, attributions, and licenses
/// ---------------------------------------------------------------------------
/// Displays essential app metadata and legally required attribution text:
///
///   1. App name ("bussin!") from [AppConstants.appName]
///   2. Version ("1.0.0") from [AppConstants.appVersion]
///   3. TransLink data attribution text (REQUIRED by TransLink Terms of Service)
///   4. OpenStreetMap attribution (for map tile data)
///   5. "Licenses" button to view open-source license information
///
/// The TransLink attribution is mandatory per their API Terms of Service
/// and must be displayed prominently in the app. The exact text is defined
/// in [AppConstants.translinkAttribution].
///
/// This widget is embedded within the Settings screen's "About"
/// CupertinoListSection.
/// ---------------------------------------------------------------------------
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- App name and version ---
        // Displays the app identity using constants defined in AppConstants.
        ListTile(
          leading: const Icon(Icons.directions_bus_filled_outlined),
          title: Text(AppConstants.appName),
          trailing: Text('v${AppConstants.appVersion}'),
        ),

        // --- TransLink data attribution (REQUIRED) ---
        // This attribution text is legally required by TransLink's API
        // Terms of Service for any app that uses their route, stop,
        // and arrival data. It must be displayed to the user.
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('TransLink Attribution'),
          subtitle: Text(
            AppConstants.translinkAttribution,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        // --- OpenStreetMap attribution ---
        // Required by the OpenStreetMap tile usage policy when displaying
        // OSM-based map tiles in the app.
        const Divider(height: 1),
        const ListTile(
          leading: Icon(Icons.map_outlined),
          title: Text('Map Data'),
          subtitle: Text(
            'Map data © Google.',
          ),
        ),

        // --- Open-source licenses button ---
        // Opens Flutter's built-in license page that aggregates all
        // LICENSE files from the app's dependencies (pubspec.yaml).
        // Note: showLicensePage is from package:flutter/material.dart,
        // imported selectively to avoid pulling in full Material.
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // showLicensePage() is a Flutter built-in that displays a
            // page listing all open-source licenses from the app's
            // package dependencies. It reads from the LicenseRegistry.
            showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
            );
          },
        ),
      ],
    );
  }
}
