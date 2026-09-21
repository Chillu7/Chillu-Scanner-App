import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/colors.dart';
import '../../core/services/image_crop_service.dart'; // NEW: crop editor helper
import '../../core/services/storage_service.dart'; // NEW: Chillu Scanner folder + permissions
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';

class ScannerScreen extends StatefulWidget {
  final bool isGalleryImport;
  const ScannerScreen({super.key, this.isGalleryImport = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // NEW: when true, the crop editor opens automatically after every capture/import.
  // Set to false to crop only via the crop button on each page card.
  static const bool _autoCropOnAdd = true;

  final List<String> _capturedImages = [];
  final List<Uint8List> _capturedBytes = [];
  final Map<int, String> _processedFilters = {}; // Index -> Filter Type
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isGalleryImport) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _importFromGallery());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _captureFromCamera());
    }
  }

  /// NEW: Opens the crop editor for [sourcePath].
  /// Returns the cropped file path, or null if the user cancelled
  /// (or if cropping is not supported, e.g. on web).
  Future<String?> _cropImage(String sourcePath) async {
    if (kIsWeb) return null;
    final cropped = await ImageCropService.cropImage(File(sourcePath));
    return cropped?.path;
  }

  /// NEW: Adds one picked image as a page. Optionally crops it first.
  /// If the user cancels the crop screen, the original image is kept.
  Future<void> _addPage(XFile photo) async {
    String pagePath = photo.path;
    Uint8List pageBytes = await photo.readAsBytes();

    if (_autoCropOnAdd) {
      final croppedPath = await _cropImage(photo.path);
      if (croppedPath != null) {
        pagePath = croppedPath;
        pageBytes = await File(croppedPath).readAsBytes();
      }
    }

    if (!mounted) return;
    setState(() {
      _capturedImages.add(pagePath);
      _capturedBytes.add(pageBytes);
      _processedFilters[_capturedImages.length - 1] = 'Original';
    });
  }

  /// NEW: Re-crops a page that is already in the list.
  Future<void> _cropExistingPage(int index) async {
    try {
      final croppedPath = await _cropImage(_capturedImages[index]);
      if (croppedPath == null) return; // user cancelled

      final bytes = await File(croppedPath).readAsBytes();
      if (!mounted) return;
      setState(() {
        _capturedImages[index] = croppedPath;
        _capturedBytes[index] = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Crop error: $e")),
      );
    }
  }

  Future<void> _captureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        await _addPage(photo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera acquisition error or denied: $e")),
      );
    }
  }

  Future<void> _importFromGallery() async {
    try {
      final List<XFile> photos = await _picker.pickMultiImage(imageQuality: 85);
      if (photos.isNotEmpty) {
        for (var photo in photos) {
          await _addPage(photo);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gallery import error: $e")),
      );
    }
  }

  void _applyFilter(int index, String filterType) {
    setState(() {
      _processedFilters[index] = filterType;
    });
  }

  // CHANGED: now uses StorageService, which requests the storage permission and
  // returns /storage/emulated/0/Chillu Scanner (or a safe fallback folder).
  Future<String> _getChilluScannerFolder() async {
    if (kIsWeb) return 'web_memory';

    final dir = await StorageService.getAppDirectory();
    return dir.path;
  }

  Future<void> _generatePdfWorkflow() async {
    if (_capturedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one page to create a PDF.")),
      );
      return;
    }

    final nameController = TextEditingController(
        text: "Scan_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}.pdf"
    );

    final String? docName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: "Document Name",
            suffixText: ".pdf",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (docName == null || docName.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final pdf = pw.Document();
      final cleanName = docName.endsWith('.pdf') ? docName : '$docName.pdf';

      for (int i = 0; i < _capturedImages.length; i++) {
        final filter = _processedFilters[i] ?? 'Original';
        Uint8List currentBytes = _capturedBytes[i];

        if (filter != 'Original') {
          img.Image? decoded = img.decodeImage(currentBytes);
          if (decoded != null) {
            if (filter == 'Grayscale') {
              decoded = img.grayscale(decoded);
            } else if (filter == 'B&W') {
              decoded = img.luminanceThreshold(decoded, threshold: 0.5);
            } else if (filter == 'Enhanced') {
              decoded = img.contrast(decoded, contrast: 120);
            }
            currentBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 80));
          }
        }

        final pdfImage = pw.MemoryImage(currentBytes);
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(pdfImage));
            },
          ),
        );
      }

      final pdfBytes = await pdf.save();
      String finalPath = '';
      int bytesSize = pdfBytes.length;

      final folderPath = await _getChilluScannerFolder();
      if (!kIsWeb) {
        final file = File('$folderPath/$cleanName');
        await file.writeAsBytes(pdfBytes);
        finalPath = file.path;
      } else {
        finalPath = '$folderPath/$cleanName';
      }

      final newDoc = DocumentModel(
        name: cleanName,
        path: finalPath,
        type: 'pdf',
        size: bytesSize,
        pages: _capturedImages.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (mounted) {
        await context.read<DocumentProvider>().createDocument(newDoc);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF created successfully inside Chillu Scanner folder: $cleanName")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate PDF: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isGalleryImport ? "Gallery Import Pipeline" : "Document Scanner"),
        actions: [
          if (_capturedImages.isNotEmpty && !_isProcessing)
            TextButton.icon(
              onPressed: _generatePdfWorkflow,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text("Create PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: _isProcessing
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Processing images and compiling PDF file...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : _capturedImages.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_album_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No pages added yet.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.isGalleryImport ? _importFromGallery : _captureFromCamera,
              icon: Icon(widget.isGalleryImport ? Icons.photo_library : Icons.camera_alt),
              label: Text(widget.isGalleryImport ? "Select Images" : "Capture Page"),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            )
          ],
        ),
      )
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.primary.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total Pages captured: ${_capturedImages.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
                      tooltip: "Add Scan Page",
                      onPressed: _captureFromCamera,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.secondary),
                      tooltip: "Add Gallery Image",
                      onPressed: _importFromGallery,
                    ),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              itemCount: _capturedImages.length,
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWideScreen ? 3 : 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 180, // CHANGED: 150 -> 180 so the extra crop button fits
              ),
              itemBuilder: (context, index) {
                final currentFilter = _processedFilters[index] ?? 'Original';
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.memory(
                            _capturedBytes[index],
                            width: 90,
                            height: 120,
                            fit: BoxFit.cover,
                          )
                              : Image.file(
                            File(_capturedImages[index]),
                            width: 90,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Page ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text("Active Filter: $currentFilter", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: ['Original', 'Grayscale', 'B&W', 'Enhanced'].map((filterName) {
                                    final isSelected = currentFilter == filterName;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 4.0),
                                      child: ChoiceChip(
                                        label: Text(filterName, style: const TextStyle(fontSize: 10)),
                                        selected: isSelected,
                                        onSelected: (val) {
                                          if (val) _applyFilter(index, filterName);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // NEW: crop button for this page
                            IconButton(
                              icon: const Icon(Icons.crop_rounded, color: AppColors.primary),
                              tooltip: "Crop",
                              onPressed: kIsWeb ? null : () => _cropExistingPage(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _capturedImages.removeAt(index);
                                  _capturedBytes.removeAt(index);
                                  final updatedFilters = <int, String>{};
                                  _processedFilters.forEach((key, value) {
                                    if (key > index) {
                                      updatedFilters[key - 1] = value;
                                    } else if (key < index) {
                                      updatedFilters[key] = value;
                                    }
                                  });
                                  _processedFilters.clear();
                                  _processedFilters.addAll(updatedFilters);
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                              onPressed: index == 0 ? null : () {
                                setState(() {
                                  final tempImg = _capturedImages[index];
                                  _capturedImages[index] = _capturedImages[index - 1];
                                  _capturedImages[index - 1] = tempImg;

                                  final tempB = _capturedBytes[index];
                                  _capturedBytes[index] = _capturedBytes[index - 1];
                                  _capturedBytes[index - 1] = tempB;

                                  final currentF = _processedFilters[index];
                                  final prevF = _processedFilters[index - 1];
                                  if (currentF != null) _processedFilters[index - 1] = currentF;
                                  if (prevF != null) _processedFilters[index] = prevF;
                                });
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}