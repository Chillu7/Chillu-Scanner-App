import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/storage_service.dart'; // adjust path if needed
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';

/// Settings applied for each compression level.
class _CompressionSettings {
  final double dpi; // Page render resolution (lower DPI = smaller file)
  final int jpegQuality; // JPEG quality from 1 to 100 (lower = smaller file)
  const _CompressionSettings(this.dpi, this.jpegQuality);
}

class PdfCompressorScreen extends StatefulWidget {
  const PdfCompressorScreen({super.key});

  @override
  State<PdfCompressorScreen> createState() => _PdfCompressorScreenState();
}

class _PdfCompressorScreenState extends State<PdfCompressorScreen> {
  // Render DPI and JPEG quality for each compression level
  static const Map<String, _CompressionSettings> _settings = {
    'Low': _CompressionSettings(150, 85),
    'Medium': _CompressionSettings(110, 65),
    'High': _CompressionSettings(80, 45),
  };

  File? _selectedFile;
  String? _originalSizeStr;
  int _originalSizeBytes = 0;
  String _compressionLevel = 'Medium'; // Low, Medium, High
  bool _isCompressing = false;
  String _progressText = '';

  // Outcome stats
  int? _compressedSizeBytes;
  String? _compressedSizeStr;
  String? _savedSizeStr;
  double? _reductionPercentage;
  String? _compressedPath;
  bool _alreadyOptimized = false;
  bool _savedInRootFolder = true;

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (bytes / 1024).floor() == 0 ? 0 : 1;
    double size = bytes.toDouble();
    if (bytes >= 1024) {
      size = bytes / 1024;
      if (size >= 1024) {
        size = size / 1024;
        i = 2;
      }
    }
    return "${size.toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  Future<void> _pickPdfDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.isNotEmpty && result.single.path != null) {
        final path = result.single.path!;
        final file = File(path);
        final sizeBytes = await file.length();
        setState(() {
          _selectedFile = file;
          _originalSizeBytes = sizeBytes;
          _originalSizeStr = _formatBytes(sizeBytes);
          // Reset values from any previous run
          _compressedSizeBytes = null;
          _compressedSizeStr = null;
          _savedSizeStr = null;
          _reductionPercentage = null;
          _compressedPath = null;
          _alreadyOptimized = false;
          _savedInRootFolder = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting document: $e")),
      );
    }
  }

  /// Converts a rasterized page (RGBA pixels) into a compressed JPEG.
  /// Transparent areas are blended onto white so they don't turn black.
  Uint8List _rasterToJpg(PdfRaster raster, int quality) {
    final src = raster.pixels;
    final w = raster.width;
    final h = raster.height;
    final rgb = Uint8List(w * h * 3);

    for (int i = 0, j = 0; i < src.length; i += 4, j += 3) {
      final a = src[i + 3];
      if (a == 255) {
        rgb[j] = src[i];
        rgb[j + 1] = src[i + 1];
        rgb[j + 2] = src[i + 2];
      } else {
        final inv = 255 - a;
        rgb[j] = (src[i] * a + 255 * inv) ~/ 255;
        rgb[j + 1] = (src[i + 1] * a + 255 * inv) ~/ 255;
        rgb[j + 2] = (src[i + 2] * a + 255 * inv) ~/ 255;
      }
    }

    final image = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: rgb.buffer,
      numChannels: 3,
    );
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  Future<void> _compressWorkflow() async {
    if (_selectedFile == null) return;

    setState(() {
      _isCompressing = true;
      _progressText = 'Starting...';
    });

    try {
      final originalBytes = await _selectedFile!.readAsBytes();
      final settings = _settings[_compressionLevel]!;

      // Build a brand-new, valid PDF one page at a time
      final newPdf = pw.Document(compress: true);
      int pageCount = 0;

      await for (final raster
      in Printing.raster(originalBytes, dpi: settings.dpi)) {
        pageCount++;
        if (mounted) {
          setState(() => _progressText = 'Compressing page $pageCount...');
        }

        final jpgBytes = _rasterToJpg(raster, settings.jpegQuality);
        final memImage = pw.MemoryImage(jpgBytes);

        // Restore the original page size (pixels -> points, 72 pt = 1 inch)
        final pageFormat = PdfPageFormat(
          raster.width * 72.0 / settings.dpi,
          raster.height * 72.0 / settings.dpi,
        );

        newPdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.SizedBox.expand(
              child: pw.Image(memImage, fit: pw.BoxFit.fill),
            ),
          ),
        );

        // Give the UI a chance to repaint between pages
        await Future.delayed(Duration.zero);
      }

      if (pageCount == 0) {
        throw Exception("The PDF has no pages or could not be read.");
      }

      Uint8List outputBytes = await newPdf.save();

      // If the result is larger than the original, keep the original bytes
      // instead of producing a bigger file.
      bool alreadyOptimized = false;
      if (outputBytes.length >= originalBytes.length) {
        outputBytes = originalBytes;
        alreadyOptimized = true;
      }

      // Save into the "Chillu Scanner" folder in root storage
      if (mounted) setState(() => _progressText = 'Saving file...');
      final outputDir = await StorageService.getAppDirectory();
      final savedInRoot = StorageService.isInRootStorage(outputDir);

      final originalName = _selectedFile!.path.split('/').last;
      final desiredName = originalName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '_compressed.pdf',
      );

      // Never overwrite an existing file: adds " (1)", " (2)", ... if needed
      final targetPath = StorageService.uniquePath(outputDir, desiredName);
      final finalName = targetPath.split('/').last;

      final File compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(outputBytes, flush: true);

      final int actualCompressedSize = await compressedFile.length();
      final savedBytes = _originalSizeBytes > actualCompressedSize
          ? _originalSizeBytes - actualCompressedSize
          : 0;
      final pct = _originalSizeBytes > 0
          ? ((_originalSizeBytes - actualCompressedSize) / _originalSizeBytes) *
          100
          : 0.0;

      if (mounted) {
        setState(() {
          _compressedSizeBytes = actualCompressedSize;
          _compressedSizeStr = _formatBytes(actualCompressedSize);
          _savedSizeStr = _formatBytes(savedBytes);
          _reductionPercentage = pct;
          _compressedPath = targetPath;
          _alreadyOptimized = alreadyOptimized;
          _savedInRootFolder = savedInRoot;
        });
      }

      final compressedDoc = DocumentModel(
        name: finalName,
        path: targetPath,
        type: 'pdf',
        size: actualCompressedSize,
        pages: pageCount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (mounted) {
        await context.read<DocumentProvider>().createDocument(compressedDoc);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alreadyOptimized
                  ? "This PDF is already well optimized. A copy of the original was saved."
                  : "PDF compressed and saved to the Chillu Scanner folder!",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Compression failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _progressText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compress PDF Utility"),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: const Icon(Icons.picture_as_pdf_rounded,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile != null
                                  ? _selectedFile!.path.split('/').last
                                  : "No Document Selected",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedFile != null
                                  ? "Original Size: $_originalSizeStr"
                                  : "Select a PDF file from storage to compress.",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isCompressing ? null : _pickPdfDocument,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white),
                        child: Text(_selectedFile != null ? "Change" : "Choose"),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_selectedFile != null) ...[
                const Text(
                  "Select Compression Level",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['Low', 'Medium', 'High'].map((level) {
                    final isSelected = _compressionLevel == level;
                    Color levelColor = AppColors.primary;
                    if (level == 'Medium') levelColor = Colors.orangeAccent;
                    if (level == 'High') levelColor = Colors.redAccent;

                    return Expanded(
                      child: Card(
                        color: isSelected ? levelColor.withOpacity(0.15) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? levelColor : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: _isCompressing
                              ? null
                              : () {
                            setState(() {
                              _compressionLevel = level;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            child: Column(
                              children: [
                                Text(
                                  level,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? levelColor : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  level == 'Low'
                                      ? "Best Quality"
                                      : level == 'Medium'
                                      ? "Balanced"
                                      : "Smallest Size",
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                if (!_isCompressing && _compressedSizeStr == null)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _compressWorkflow,
                      icon: const Icon(Icons.speed_rounded),
                      label: const Text("Optimize & Reduce Size",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],

              if (_isCompressing)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _progressText.isEmpty
                              ? "Compressing..."
                              : _progressText,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_compressedSizeStr != null) ...[
                const SizedBox(height: 20),
                const Text(
                  "Compression Results",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.accent),
                ),
                const SizedBox(height: 12),
                Card(
                  color: AppColors.accent.withOpacity(0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Original Document Size:"),
                            Text(_originalSizeStr!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Compressed Output Size:"),
                            Text(_compressedSizeStr!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent)),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Disk Space Saved:"),
                            Text(_savedSizeStr!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orangeAccent)),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Size Reduction:"),
                            Text(
                                "-${_reductionPercentage!.toStringAsFixed(1)}%",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_alreadyOptimized) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "This file is already small or optimized. Compressing it further would have increased its size, so a copy of the original was saved.",
                    style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                  ),
                ],
                if (!_savedInRootFolder) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "Storage permission was not granted, so the file was saved in the app's private folder instead of the device root. Allow 'All files access' for this app to save into the root Chillu Scanner folder.",
                    style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  "Saved to:\n$_compressedPath",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
