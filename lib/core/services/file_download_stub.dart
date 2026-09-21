import 'dart:typed_data';

/// Stub used on Android/iOS. Browser downloads only exist on web, and this
/// function is never called on mobile (calls are guarded with kIsWeb).
Future<void> downloadFileBytes(
    Uint8List bytes,
    String fileName, {
      String mimeType = 'application/pdf',
    }) async {
  throw UnsupportedError('Browser downloads are only available on web.');
}
