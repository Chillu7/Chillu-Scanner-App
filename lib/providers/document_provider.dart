import 'dart:io';
import 'package:flutter/material.dart';
import '../database/local_database.dart';
import '../models/document_model.dart';

class DocumentProvider extends ChangeNotifier {
  List<DocumentModel> _documents = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortBy = 'Newest';

  List<DocumentModel> get documents {
    List<DocumentModel> filtered = _documents.where((doc) {
      return doc.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (_sortBy == 'Newest') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortBy == 'Oldest') {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (_sortBy == 'Largest') {
      filtered.sort((a, b) => b.size.compareTo(a.size));
    } else if (_sortBy == 'Smallest') {
      filtered.sort((a, b) => a.size.compareTo(b.size));
    } else if (_sortBy == 'Name') {
      filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return filtered;
  }

  bool get isLoading => _isLoading;
  String get sortBy => _sortBy;
  String get searchQuery => _searchQuery;

  int get totalDocumentsCount => _documents.length;
  double get totalStorageUsedMB {
    int totalBytes = _documents.fold(0, (sum, item) => sum + item.size);
    return totalBytes / (1024 * 1024);
  }

  Future<void> refreshDocuments() async {
    _isLoading = true;
    notifyListeners();
    try {
      _documents = await LocalDatabase.instance.fetchAllDocuments();
    } catch (e) {
      debugPrint("Error loading from DB: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  void loadMockDocuments() async {
    await refreshDocuments();
    if (_documents.isEmpty) {
      // If DB is empty, let's load initial state or leave empty for real capture
    }
  }

  Future<void> createDocument(DocumentModel doc) async {
    await LocalDatabase.instance.insertDocument(doc);
    await refreshDocuments();
  }

  Future<void> renameDocument(int id, String newName) async {
    final docIndex = _documents.indexWhere((element) => element.id == id);
    if (docIndex != -1) {
      final doc = _documents[docIndex];
      final File oldFile = File(doc.path);
      final String dirPath = oldFile.parent.path;
      final String cleanName = newName.endsWith('.pdf') ? newName : '$newName.pdf';
      final String newPath = '$dirPath/$cleanName';

      try {
        if (await oldFile.exists()) {
          await oldFile.rename(newPath);
        }
        final updatedDoc = doc.copyWith(
          name: cleanName,
          path: newPath,
          updatedAt: DateTime.now(),
        );
        await LocalDatabase.instance.updateDocument(updatedDoc);
        await refreshDocuments();
      } catch (e) {
        debugPrint("Error renaming document file: $e");
      }
    }
  }

  Future<void> deleteDocument(int id) async {
    final docIndex = _documents.indexWhere((element) => element.id == id);
    if (docIndex != -1) {
      final doc = _documents[docIndex];
      try {
        final file = File(doc.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Error deleting file: $e");
      }
      await LocalDatabase.instance.deleteDocument(id);
      await refreshDocuments();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sortOption) {
    _sortBy = sortOption;
    notifyListeners();
  }

  void clearCache() {
    // Clean temporary cache files if any
    notifyListeners();
  }
}
