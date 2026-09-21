import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../core/constants/colors.dart';

class PdfViewerScreen extends StatelessWidget {
  final DocumentModel document;

  const PdfViewerScreen({super.key, required this.document});

  void _shareDocument(BuildContext context) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sharing is handled through web browser action features.")),
        );
        return;
      }
      final file = File(document.path);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(document.path)], text: 'Sharing ${document.name} from Chillu Scanner.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Physical file missing from local device storage.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share document: $e")),
      );
    }
  }

  void _printDocument(BuildContext context) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Printing is handled through web browser actions.")),
        );
        return;
      }
      final file = File(document.path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await Printing.layoutPdf(onLayout: (_) => bytes, name: document.name);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Physical file missing from storage.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Printing system error: $e")),
      );
    }
  }

  void _renameDialog(BuildContext context) async {
    final controller = TextEditingController(text: document.name.replaceAll('.pdf', ''));
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "New Name",
            suffixText: ".pdf",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text("Rename"),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && context.mounted) {
      await context.read<DocumentProvider>().renameDocument(document.id!, newName);
      Navigator.pop(context);
    }
  }

  void _deleteDocument(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("Are you absolutely sure you want to permanently delete this document from device storage? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<DocumentProvider>().deleteDocument(document.id!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(document.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded), tooltip: "Share PDF", onPressed: () => _shareDocument(context)),
          IconButton(icon: const Icon(Icons.print_rounded), tooltip: "Print Document", onPressed: () => _printDocument(context)),
        ],
      ),
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.bgDark : Colors.grey[200],
        child: Column(
          children: [
            Expanded(
              child: kIsWeb
                  ? const Center(
                      child: Text(
                        "Web Preview Mode Active.",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    )
                  : FutureBuilder<bool>(
                      future: File(document.path).exists(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.data == true) {
                          return PdfPreview(
                            build: (format) => File(document.path).readAsBytes(),
                            allowSharing: false,
                            allowPrinting: false,
                            canChangePageFormat: false,
                            canChangeOrientation: false,
                            loadingWidget: const Center(child: CircularProgressIndicator()),
                          );
                        } else {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orangeAccent),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Physical file not found on local storage.",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Expected path: ${document.path}",
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
            ),
            // Bottom Action bar menu options with SingleChildScrollView to prevent overflow
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Theme.of(context).cardTheme.color,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _renameDialog(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text("Rename"),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _deleteDocument(context),
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: const Text("Delete"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
