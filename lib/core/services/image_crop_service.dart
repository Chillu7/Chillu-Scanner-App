import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../constants/colors.dart'; // adjust path if needed

/// Opens a full-screen crop editor for a scanned or picked image.
/// Works fully offline (uses the native uCrop editor on Android).
///
/// Suggested path in your project: lib/core/services/image_crop_service.dart
class ImageCropService {
  /// Returns the cropped image file, or null if the user cancelled.
  static Future<File?> cropImage(File source) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: source.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95, // keep high quality; PDF compression happens later
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Document',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false, // free-form crop, like a document scanner
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Document',
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    if (cropped == null) return null; // user cancelled the crop screen
    return File(cropped.path);
  }
}
