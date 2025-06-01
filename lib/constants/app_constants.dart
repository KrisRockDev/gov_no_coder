import 'dart:io'; // Для Platform.pathSeparator
import 'package:flutter/material.dart';

class AppConstants {
  static const String appVersion = "1.0.0 (Flutter)";
  static const String lastDirectoryKey = "last_directory_path_v1_flutter";

  // Имена файлов для промптов
  static const String startPromptFileName = "prompt_start.txt";
  static const String endPromptFileName = "prompt_finish.txt";


  // Соотношение панелей
  static const int leftPanelFlex = 2;  // 20%
  static const int rightPanelFlex = 8; // 80%

  static const Set<String> textExtensions = {
    ".py", ".txt", ".md", ".json", ".yaml", ".yml", ".html", ".htm",
    ".css", ".js", ".csv", ".log", ".ini", ".cfg", ".xml", ".sh", ".bat",
    ".gitignore", ".dockerfile", "readme", ".env", ".dart", ".java", ".kt",
    ".c", ".cpp", ".h", ".hpp", ".cs", ".go", ".rs", ".swift", ".php", ".rb"
  };

  // Имя переменной было изменено с ignoreDirs на ignoreDirsAndFiles, чтобы отразить, что она содержит и файлы.
  static const Set<String> ignoreDirsAndFiles = {
    ".git", ".venv", "venv", ".vscode", ".idea", "node_modules", "__pycache__",
    "build", "dist", "target", ".pytest_cache", ".mypy_cache",
    // Flutter/Dart specific
    ".dart_tool", ".packages", "ios", "android", "web", "windows", "linux", "macos",
    // Файлы промптов
    startPromptFileName, endPromptFileName,
  };

  static TextStyle hintStyle = TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600);

  static String pathSeparator = Platform.pathSeparator;

  // Системный промпт для обновления файлов (оставляем как есть, но его загрузка из файла не предполагается)
  // Этот промпт будет использоваться, если поле конечного промпта пусто при копировании всего.
  static const String defaultUpdateSystemPrompt = """""";
}