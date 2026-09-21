// Cross-platform "download file" helper.
//
// Suggested path: lib/core/services/file_download.dart
// Put file_download_web.dart and file_download_stub.dart in the SAME folder.
//
// Usage (only call this on web, guard with kIsWeb):
//   await downloadFileBytes(pdfBytes, 'my_document.pdf');
//
// The correct implementation is chosen at compile time:
//  - web builds    -> file_download_web.dart (real browser download)
//  - other builds  -> file_download_stub.dart (does nothing useful, never called)
export 'file_download_stub.dart'
if (dart.library.js_interop) 'file_download_web.dart';
