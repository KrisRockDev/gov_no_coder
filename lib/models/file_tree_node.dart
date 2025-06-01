import 'package:flutter/foundation.dart'; // Для kIsWeb

class FileTreeNode {
  final String path;
  final String name;
  final bool isDirectory;
  List<FileTreeNode> children;
  bool isExpanded;
  // isSelected будет управляться через selectedPathsProvider, чтобы не дублировать состояние

  FileTreeNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.children = const [],
    this.isExpanded = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTreeNode &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() {
    return 'FileTreeNode{path: $name, isDirectory: $isDirectory, children: ${children.length}, isExpanded: $isExpanded}';
  }

  // Метод для глубокого копирования, если понадобится изменять узлы не мутируя оригинал
  FileTreeNode copyWith({
    String? path,
    String? name,
    bool? isDirectory,
    List<FileTreeNode>? children,
    bool? isExpanded,
  }) {
    return FileTreeNode(
      path: path ?? this.path,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      children: children ?? List.from(this.children.map((child) => child.copyWith())), // Глубокое копирование детей
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  // Статический метод для создания корневого узла, если выбранная директория сама является узлом
  static FileTreeNode createRoot(String path, String name, List<FileTreeNode> children) {
      return FileTreeNode(
          path: path,
          name: name,
          isDirectory: true,
          children: children,
          isExpanded: true, // Корень обычно развернут
      );
  }
}