import 'dart:io'; // Для Platform.pathSeparator
import 'package:flutter/material.dart';

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

  static TextStyle hintStyle = TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600);

  static String pathSeparator = Platform.pathSeparator;

  // Новый промпт по умолчанию
  static const String defaultUpdateSystemPrompt = """Предоставь код для обновления файлов проекта.
Ответ должен быть ТОЛЬКО в формате:
путь/к/файлу1_относительно_корня_проекта
```
полный код файла 1
```
путь/к/файлу2_относительно_корня_проекта
```
полный код файла 2
```
... и так далее для каждого файла.

ЗАПРЕЩЕНО:
- Любые комментарии, пояснения, приветствия или благодарности вне блоков кода.
- Указание типа языка программирования после ``` (например, ```dart или ```yaml). Используй только ```.
- Пустые строки между путем к файлу и открывающим ```.
- Пустые строки между закрывающим ``` и следующим путем к файлу (если есть).
- Любой текст до первого пути к файлу или после последнего закрывающего ```.

Каждый файл должен быть представлен путем и следующим за ним блоком кода. Убедись, что пути корректны и код полный.""";
}