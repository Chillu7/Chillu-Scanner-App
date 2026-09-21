import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Triggers a browser download of [bytes] with the given [fileName].
/// The file lands in the user's normal Downloads folder.
Future<void> downloadFileBytes(
    Uint8List bytes,
    String fileName, {
      String mimeType = 'application/pdf',
    }) async {
  // Wrap the bytes in a Blob and create a temporary object URL for it
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  // Click a hidden <a download> link to start the download
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Free the temporary URL
  web.URL.revokeObjectURL(url);
}
