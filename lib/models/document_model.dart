class DocumentModel {
  final int? id;
  final String name;
  final String path;
  final String type; // e.g., 'pdf', 'image'
  final int size; // in bytes
  final int pages;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentModel({
    this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.pages,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'size': size,
      'pages': pages,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'],
      name: map['name'],
      path: map['path'],
      type: map['type'],
      size: map['size'],
      pages: map['pages'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  DocumentModel copyWith({
    int? id,
    String? name,
    String? path,
    String? type,
    int? size,
    int? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      pages: pages ?? this.pages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
