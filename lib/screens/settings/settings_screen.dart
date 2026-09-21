import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/document_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final docProvider = Provider.of<DocumentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // Theme Option Tile
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 1,
            child: SwitchListTile(
              secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppColors.primary,
              ),
              title: const Text("Dark Theme Mode", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text("Toggle professional application appearance preference.", style: TextStyle(fontSize: 12)),
              value: themeProvider.isDarkMode,
              onChanged: (bool value) {
                themeProvider.toggleTheme();
              },
            ),
          ),

          // Cache / Local Storage Card breakdown
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage_rounded, color: Colors.orangeAccent),
                      SizedBox(width: 10),
                      Text("Local Storage Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Total Document Count: ${docProvider.totalDocumentsCount}", style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text("Metadata Cache Allocation: ${docProvider.totalStorageUsedMB.toStringAsFixed(2)} MB", style: const TextStyle(fontSize: 13)),
                  const Divider(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      docProvider.clearCache();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("All local temporary image artifacts cleared.")),
                      );
                    },
                    icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                    label: const Text("Clear Temporary Cache"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  )
                ],
              ),
            ),
          ),

          // Application Info
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 1,
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                  title: Text("App Information", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text("Chillu Scanner v1.0.0 (Offline-First Android production engine)", style: TextStyle(fontSize: 12)),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: AppColors.accent),
                  title: Text("Privacy Information", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text("100% Secure. All data processing occurs entirely within the device boundaries.", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
