import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chillu_scanner/core/constants/colors.dart';

/// Button that lets web visitors download the Android APK from GitHub Releases.
///
/// Suggested path: lib/widgets/download_button.dart
class DownloadButton extends StatelessWidget {
  // Replace with your actual GitHub Release APK link, e.g.:
  // https://github.com/<username>/<repo>/releases/download/v1.0.0/chillu_scanner.apk
  static const String apkUrl = 'https://github.com/Chillu7/Chillu-Scanner-App/releases/download/v1.0.0/app-arm64-v8a-release.apk';

  const DownloadButton({super.key});

  Future<void> _downloadApk(BuildContext context) async {
    final Uri url = Uri.parse(apkUrl);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Could not open the download link');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _downloadApk(context),
      icon: const Icon(Icons.android),
      label: const Text(
        'Download App (Android APK)',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}