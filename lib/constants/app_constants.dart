import 'dart:io'; // Для Platform.pathSeparator
import 'package:flutter/material.dart'; // <--- ДОБАВЛЕН ЭТОТ ИМПОРТ

class AppConstants {
  static const String appVersion = "1.0.0 (Flutter)";
  static const String lastDirectoryKey = "last_directory_path_v1_flutter";

  // Соотношение панелей
  static const int leftPanelFlex = 2;  // 20%
  static const int rightPanelFlex = 8; // 80%

  static const Set<String> textExtensions = {
    ".py", ".txt", ".md", ".json", ".yaml", ".yml", ".html", ".htm",
    ".css", ".js", ".csv", ".log", ".ini", ".cfg", ".xml", ".sh", ".bat",
    ".gitignore", ".dockerfile", "readme", ".env", ".dart", ".java", ".kt",
    ".c", ".cpp", ".h", ".hpp", ".cs", ".go", ".rs", ".swift", ".php", ".rb"
  };

  static const Set<String> ignoreDirs = {
    ".git", ".venv", "venv", ".vscode", ".idea", "node_modules", "__pycache__",
    "build", "dist", "target", ".pytest_cache", ".mypy_cache",
    // Flutter/Dart specific
    ".dart_tool", ".packages", "ios", "android", "web", "windows", "linux", "macos"
  };

  // Placeholder стиль
  static TextStyle hintStyle = TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600); // Используем Colors.grey.shade600 для лучшей видимости

  static String pathSeparator = Platform.pathSeparator;
}