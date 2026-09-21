import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Central place that decides where the app saves scanned and compressed files.
/// Target (Android): /storage/emulated/0/Chillu Scanner
/// Fallback (iOS, or permission denied): <app documents>/Chillu Scanner
class StorageService {
  static const String folderName = 'Chillu Scanner';
  static const String _androidRoot = '/storage/emulated/0';

  static Future<bool> _ensureAndroidPermission() async {
    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

    if (sdkInt >= 30) {
      // Android 11+: "All files access" is needed to write to the root folder
      if (await Permission.manageExternalStorage.isGranted) return true;
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } else {
      // Android 10 and below
      if (await Permission.storage.isGranted) return true;
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  /// Returns the "Chillu Scanner" directory, creating it if needed.
  static Future<Directory> getAppDirectory() async {
    if (Platform.isAndroid) {
      final granted = await _ensureAndroidPermission();
      if (granted) {
        try {
          final dir = Directory('$_androidRoot/$folderName');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        } catch (_) {
          // Fall through to the fallback below
        }
      }
    }

    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// True when the directory is the real "Chillu Scanner" folder in root storage.
  static bool isInRootStorage(Directory dir) {
    return Platform.isAndroid && dir.path.startsWith(_androidRoot);
  }

  /// Returns a file path inside [dir] that does not overwrite an existing file.
  /// Example: scan.pdf -> scan (1).pdf
  static String uniquePath(Directory dir, String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot == -1 ? fileName : fileName.substring(0, dot);
    final ext = dot == -1 ? '' : fileName.substring(dot);

    String candidate = '${dir.path}/$fileName';
    int counter = 1;
    while (File(candidate).existsSync()) {
      candidate = '${dir.path}/$base ($counter)$ext';
      counter++;
    }
    return candidate;
  }
}
