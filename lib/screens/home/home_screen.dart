import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../providers/document_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../scanner/scanner_screen.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';
import '../pdf_compressor/pdf_compressor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().loadMockDocuments();
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);
    final recentDocs = docProvider.documents.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Chillu Scanner",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Offline analytics summary running locally.")),
              );
            },
          )
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dashboard Header Stats
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text("Total Docs", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              "${docProvider.totalDocumentsCount}",
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 35, color: Colors.white30),
                        Column(
                          children: [
                            const Text("Local Storage", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              "${docProvider.totalStorageUsedMB.toStringAsFixed(2)} MB",
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Core Utility Actions Title
                  const Text(
                    "Quick Utilities",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Grid Actions kama SliverGrid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              delegate: SliverChildListDelegate([
                CustomActionButton(
                  label: "Scan Document",
                  icon: Icons.camera_alt_rounded,
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScannerScreen(isGalleryImport: false)),
                    );
                  },
                ),
                CustomActionButton(
                  label: "Import Images",
                  icon: Icons.photo_library_rounded,
                  color: AppColors.secondary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScannerScreen(isGalleryImport: true)),
                    );
                  },
                ),
                CustomActionButton(
                  label: "Compress PDF",
                  icon: Icons.picture_as_pdf_rounded,
                  color: Colors.orangeAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PdfCompressorScreen()),
                    );
                  },
                ),
                CustomActionButton(
                  label: "Storage Clean",
                  icon: Icons.cleaning_services_rounded,
                  color: AppColors.accent,
                  onTap: () {
                    docProvider.clearCache();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Temporary file directory cleaned successfully.")),
                    );
                  },
                ),
              ]),
            ),
          ),

          // Recent Documents Section Header na List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    "Recent Documents",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          recentDocs.isEmpty
              ? SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: const SizedBox(
                height: 155,
                child: EmptyStateWidget(message: "No recent scans or imported documents found."),
              ),
            ),
          )
              : SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final doc = recentDocs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 1,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 28),
                        ),
                        title: Text(
                          doc.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "${DateFormat('MMM dd, yyyy • hh:mm a').format(doc.createdAt)} | ${doc.pages} ${doc.pages == 1 ? 'page' : 'pages'}",
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        trailing: Text(
                          _formatBytes(doc.size),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PdfViewerScreen(document: doc)),
                          );
                        },
                      ),
                    ),
                  );
                },
                childCount: recentDocs.length,
              ),
            ),
          ),

          // Nafasi ya ziada chini kabisa kuzuia mgandamizo
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }
}