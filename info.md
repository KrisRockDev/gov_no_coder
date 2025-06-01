pubspec.yaml
```yaml
name: file_content_aggregator
description: A Flutter application to aggregate content from text files in a directory.
publish_to: 'none' # Remove this line if you plan to publish to pub.dev

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0' # Убедитесь, что версия SDK соответствует

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.9 # Для управления состоянием
  file_picker: ^6.1.1     # Для выбора директории
  path: ^1.8.3            # Для работы с путями
  shared_preferences: ^2.2.2 # Для сохранения настроек
  clipboard: ^0.1.3       # Для копирования в буфер обмена
  material_design_icons_flutter: ^7.0.7296 # Для дополнительных иконок (если понадобятся, стандартных Material много)
  
  # Используйте flutter_lints для анализа кода
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg
  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
  #       - asset: fonts/Schyler-Italic.ttf
  #         style: italic
```

lib/main.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/screens/home_screen.dart';
import 'package:file_content_aggregator/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Важно для shared_preferences и других плагинов
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'File Content Aggregator',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.blue.withOpacity(0.05),
        ),
        tooltipTheme: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 500),
          textStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onInverseSurface),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
         inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.blue.withOpacity(0.1),
        ),
        tooltipTheme: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 500),
          textStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onInverseSurface),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      themeMode: themeMode,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

lib/constants/app_constants.dart
```dart
import 'dart:io'; // Для Platform.pathSeparator

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
  static const TextStyle hintStyle = TextStyle(fontStyle: FontStyle.italic, color: Colors.grey);

  static String pathSeparator = Platform.pathSeparator;
}
```

lib/models/file_tree_node.dart
```dart
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
```
lib/utils/file_utils.dart
```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_content_aggregator/constants/app_constants.dart';

class FileUtils {
  static bool isLikelyTextFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    // Проверка по частям пути на игнорируемые директории
    List<String> pathParts = p.split(filePath);
    for (String part in pathParts) {
      if (AppConstants.ignoreDirs.contains(part.toLowerCase())) {
        return false;
      }
      // Игнорирование скрытых директорий (кроме .gitattributes, .gitignore и т.п. в корне)
      if (part.startsWith('.') && part.length > 1 && pathParts.indexOf(part) < pathParts.length -1) {
         // Если это директория и она скрытая (не сам файл)
         if (Directory(p.joinAll(pathParts.sublist(0, pathParts.indexOf(part) + 1))).existsSync()) {
            return false;
         }
      }
    }

    final extension = p.extension(filePath).toLowerCase();
    final nameLower = p.basename(filePath).toLowerCase();

    if (AppConstants.textExtensions.contains(nameLower) || AppConstants.textExtensions.contains(extension)) {
      return true;
    }

    // Если расширение неизвестно или отсутствует, пытаемся прочитать как текст
    if (extension.isEmpty || !AppConstants.textExtensions.contains(extension)) {
      try {
        // Читаем небольшой кусок, чтобы проверить на бинарность (упрощенная проверка)
        final content = file.readAsStringSync(encoding: SystemEncoding(),ान�); // Используем SystemEncoding, т.к. utf-8 может упасть на бинарных
        // Проверка на нулевые байты или непечатаемые символы может быть добавлена здесь
        // Для простоты, если чтение удалось без ошибок, считаем текстовым
        return true;
      } catch (e) {
        // Если ошибка чтения (например, бинарный файл), то это не текстовый файл
        return false;
      }
    }
    return false;
  }
}
```
lib/services/preferences_service.dart
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';

class PreferencesService {
  Future<String?> getLastDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.lastDirectoryKey);
  }

  Future<void> saveLastDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.lastDirectoryKey, path);
  }
}
```

lib/services/file_system_service.dart
```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_content_aggregator/models/file_tree_node.dart';
import 'package:file_content_aggregator/utils/file_utils.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';

class FileSystemService {
  Future<List<FileTreeNode>> getDirectoryTree(String directoryPath, {String filter = ""}) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw Exception("Directory not found: $directoryPath");
    }

    List<FileTreeNode> buildNodes(Directory currentDir, String currentPathFilter) {
      List<FileTreeNode> nodes = [];
      try {
        final entities = currentDir.listSync(recursive: false, followLinks: false);
        entities.sort((a, b) { // Сначала папки, потом файлы, затем по имени
          bool aIsDir = a is Directory;
          bool bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
        });

        for (var entity in entities) {
          final entityName = p.basename(entity.path);
          final entityPath = entity.path;

          if (AppConstants.ignoreDirs.contains(entityName.toLowerCase())) {
            continue;
          }
          if (entityName.startsWith('.') && entity is Directory && entityName != ".git") { // Пропускаем скрытые папки, кроме специфичных
             bool isAlwaysIgnored = true;
             for(var ext in AppConstants.textExtensions){ // Проверяем, не является ли скрытый элемент файлом из списка textExtensions
                 if(entityName.toLowerCase() == ext || entityName.toLowerCase().endsWith(ext)){
                    isAlwaysIgnored = false;
                    break;
                 }
             }
             if(isAlwaysIgnored) continue;
          }


          final bool isDir = entity is Directory;
          List<FileTreeNode> children = [];

          bool matchesFilter = true;
          if (currentPathFilter.isNotEmpty) {
            matchesFilter = entityName.toLowerCase().contains(currentPathFilter.toLowerCase());
          }

          if (isDir) {
            // Рекурсивно строим дочерние узлы, если текущая папка или ее дети могут соответствовать фильтру
            // Для упрощения фильтрации на верхнем уровне, передаем фильтр дальше.
            // Более сложная фильтрация (как в Python, где родитель показывается, если ребенок подходит)
            // требует двухпроходного алгоритма или более сложной логики.
            // Здесь, если имя папки не подходит, ее дети не будут показаны (если фильтр активен).
            // Чтобы показать родителя, если дети подходят, нужно сканировать глубже и потом фильтровать.
            // Для простоты, пока оставим так: если имя папки не подходит, она не показывается с фильтром.
            // Либо, сначала строим все дерево, а потом фильтруем видимость.
            
            // Упрощенный подход: строим детей, если имя папки подходит ИЛИ фильтр пуст.
            // Для более точной фильтрации, как в оригинале, потребуется сначала собрать все пути, отфильтровать,
            // а потом строить дерево только из видимых.
            // Пока оставим так: фильтр применяется к текущему уровню.
            children = buildNodes(entity as Directory, currentPathFilter);
             if (currentPathFilter.isNotEmpty && !matchesFilter && children.isEmpty) {
               continue; // Не добавляем папку, если она сама не матчится и дети не матчатся (или их нет)
             }

          } else { // Это файл
            if (currentPathFilter.isNotEmpty && !matchesFilter) {
              continue;
            }
            if (!FileUtils.isLikelyTextFile(entityPath)) {
              continue;
            }
          }
          
          // Если фильтр активен, и ни сам узел, ни его дети (для папок) не соответствуют, пропускаем
          if (currentPathFilter.isNotEmpty && !matchesFilter && (isDir && children.isEmpty)) {
              continue;
          }

          nodes.add(FileTreeNode(
            path: entityPath,
            name: entityName,
            isDirectory: isDir,
            children: children,
          ));
        }
      } catch (e) {
        // Ошибки доступа и т.п.
        // Можно добавить узел с сообщением об ошибке
        // print("Error listing directory ${currentDir.path}: $e");
      }
      return nodes;
    }
    
    // Начальный вызов для корневой директории.
    // Чтобы фильтрация работала как в оригинале (показывая родительские папки, если дочерние элементы соответствуют фильтру),
    // нужна более сложная логика. Сначала нужно построить все дерево или список всех путей,
    // затем применить фильтр, чтобы определить видимые узлы, и только потом строить FileTreeNode структуру для отображения.

    // Реализуем более точную фильтрацию:
    List<String> getAllFilesAndDirs(String rootPath) {
        List<String> paths = [];
        try {
            Directory root = Directory(rootPath);
            if (!root.existsSync()) return paths;

            root.listSync(recursive: true, followLinks: false).forEach((entity) {
                final entityName = p.basename(entity.path);
                bool shouldIgnore = AppConstants.ignoreDirs.contains(entityName.toLowerCase());
                
                // Проверка на скрытые директории в пути
                List<String> parts = p.split(entity.path);
                for (int i = 0; i < parts.length -1; i++) { // -1 чтобы не проверять сам файл/папку как родителя
                    if (parts[i].startsWith('.') && parts[i].length > 1) {
                         // Проверяем, не является ли часть пути одной из корневых игнорируемых папок
                         if (AppConstants.ignoreDirs.contains(parts[i].toLowerCase())) {
                             shouldIgnore = true;
                             break;
                         }
                         // Проверяем, является ли скрытая часть пути директорией
                         String currentSubPath = p.joinAll(parts.sublist(0, i + 1));
                         if (Directory(currentSubPath).existsSync()) {
                            bool isTextFileInHiddenDir = false;
                            if(entity is File) {
                                for(var ext in AppConstants.textExtensions){
                                    if(entityName.toLowerCase() == ext || entityName.toLowerCase().endsWith(ext)){
                                        isTextFileInHiddenDir = true;
                                        break;
                                    }
                                }
                            }
                            if(!isTextFileInHiddenDir){ // Если это не специальный текстовый файл в скрытой папке
                                shouldIgnore = true;
                                break;
                            }
                         }
                    }
                }


                if (!shouldIgnore) {
                    if (entity is File) {
                        if (FileUtils.isLikelyTextFile(entity.path)) {
                            paths.add(entity.path);
                        }
                    } else if (entity is Directory) {
                        paths.add(entity.path);
                    }
                }
            });
        } catch (e) {
            // print("Error in getAllFilesAndDirs for $rootPath: $e");
        }
        return paths;
    }

    Set<String> getVisiblePaths(String rootPath, String filterText) {
        final allPaths = getAllFilesAndDirs(rootPath);
        if (filterText.isEmpty) return Set.from(allPaths);

        final Set<String> visible = {};
        final filterLower = filterText.toLowerCase();

        for (final path in allPaths) {
            if (p.basename(path).toLowerCase().contains(filterLower)) {
                visible.add(path);
                // Добавляем всех родителей до корня сканирования
                String current = path;
                while (p.dirname(current) != p.dirname(rootPath) && current != rootPath) { // Условие остановки
                    current = p.dirname(current);
                    if (current == rootPath || current == p.dirname(rootPath)) break; // Не добавлять родителя самого rootPath
                     if (allPaths.contains(current)) { // Убедимся, что родитель вообще был в списке (не отфильтрован по ignoreDirs)
                        visible.add(current);
                    } else {
                        // Если родителя нет в allPaths, значит он был отфильтрован ранее, не добавляем его
                        // Но нам нужно найти ближайшего существующего родителя из allPaths
                        String tempParent = current;
                        bool foundValidParent = false;
                        while(p.dirname(tempParent) != p.dirname(rootPath) && tempParent != rootPath) {
                            tempParent = p.dirname(tempParent);
                             if (allPaths.contains(tempParent)) {
                                visible.add(tempParent);
                                foundValidParent = true;
                                break;
                            }
                             if (tempParent == rootPath || tempParent == p.dirname(rootPath)) break;
                        }
                        if(foundValidParent) break; // Выходим из цикла добавления родителей, если нашли валидного
                    }

                }
            }
        }
        // Гарантированно добавляем сам rootPath, если он не был отфильтрован ранее и если что-то видимо
        if (visible.isNotEmpty && allPaths.contains(rootPath)) {
           visible.add(rootPath);
        }
        return visible;
    }
    
    final visiblePaths = getVisiblePaths(directoryPath, filter);

    List<FileTreeNode> buildFilteredTree(Directory currentDir, Set<String> visible) {
        List<FileTreeNode> nodes = [];
        try {
            if (!visible.contains(currentDir.path) && currentDir.path != directoryPath) { // Не обрабатываем если сама папка невидима (кроме корня)
                // print("Skipping invisible dir: ${currentDir.path}");
                // return nodes; // Это вызовет проблемы, если папка невидима, но дети видимы.
                // Вместо этого, если папка невидима, но дети видимы, мы должны все равно ее обработать,
                // но не создавать для нее узел, а только для ее видимых детей.
                // Либо, если currentDir.path == directoryPath, то мы всегда его обрабатываем.
            }

            final entities = currentDir.listSync(recursive: false, followLinks: false);
            entities.sort((a, b) {
                bool aIsDir = a is Directory;
                bool bIsDir = b is Directory;
                if (aIsDir && !bIsDir) return -1;
                if (!aIsDir && bIsDir) return 1;
                return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
            });

            for (var entity in entities) {
                if (!visible.contains(entity.path)) {
                    // print("Skipping invisible entity: ${entity.path}");
                    continue;
                }

                final entityName = p.basename(entity.path);
                final bool isDir = entity is Directory;
                
                if (isDir) {
                    nodes.add(FileTreeNode(
                        path: entity.path,
                        name: entityName,
                        isDirectory: true,
                        children: buildFilteredTree(entity as Directory, visible),
                    ));
                } else if (entity is File) { // Убедимся что это файл и он текстовый (уже проверено в getVisiblePaths через isLikelyTextFile)
                     nodes.add(FileTreeNode(
                        path: entity.path,
                        name: entityName,
                        isDirectory: false,
                    ));
                }
            }
        } catch (e) {
            // print("Error building filtered tree for ${currentDir.path}: $e");
        }
        return nodes;
    }

    // Если после фильтрации ничего не осталось, кроме, возможно, самого rootPath,
    // и фильтр был непустой, то возвращаем пустой список, чтобы показать "Ничего не найдено".
    // Исключение: если rootPath видим, но в нем нет видимых детей (например, пустая папка, но имя rootPath совпало с фильтром)
    if (filter.isNotEmpty && visiblePaths.isEmpty) {
        return [];
    }
    if (filter.isNotEmpty && visiblePaths.length == 1 && visiblePaths.first == directoryPath && Directory(directoryPath).listSync().isEmpty) {
        // Если только корень видим, и он пуст, и был фильтр, то это как "ничего не найдено в..."
        // Но если имя корня само по себе подошло под фильтр, его нужно показать.
        // Поэтому, если visiblePaths содержит только rootPath, и он директория, строим его.
    }


    // Создаем корневой узел (саму выбранную директорию) и его дочерние элементы
    // Это необходимо, чтобы дерево начиналось с выбранной папки.
    // Однако, FileTreeView ожидает список узлов, поэтому мы вернем детей корневого узла.
    // Либо FileTreeView должен уметь работать с одним корневым узлом.
    // Для простоты, будем возвращать список узлов внутри выбранной директории.
    
    // return buildFilteredTree(dir, visiblePaths);
    // Обернем результат в один корневой "виртуальный" узел, если нужно
    // Но лучше, если getDirectoryTree возвращает список узлов ВНУТРИ directoryPath

    // Корректировка: getDirectoryTree должна возвращать список узлов ПЕРВОГО УРОВНЯ ВНУТРИ directoryPath
    // А сам directoryPath - это контекст.
    // Поэтому buildFilteredTree вызывается для `dir`.

    // Если сам `directoryPath` не видим (что маловероятно, если он корень сканирования и не игнорируется),
    // то ничего не будет. Но `getVisiblePaths` должен его включать, если он валиден.
    if (!visiblePaths.contains(directoryPath) && visiblePaths.isNotEmpty) {
        // Это странная ситуация, корень должен быть видим, если есть видимые дети.
        // getVisiblePaths должен был добавить корень.
        // print("Warning: Root directory $directoryPath not in visible paths, but children are.");
    }
    
    return buildFilteredTree(dir, visiblePaths);
  }


  Future<String> aggregateFileContents(
    Set<String> selectedPaths,
    String baseDirectoryPath,
    String startPrompt,
    String endPrompt,
  ) async {
    final buffer = StringBuffer();
    final List<String> sortedPaths = selectedPaths.toList()..sort();
    final Set<String> processedFiles = {}; // Для избежания дублирования при выборе папки и файла в ней

    if (startPrompt.isNotEmpty) {
      buffer.writeln(startPrompt.trim());
      buffer.writeln(); // Дополнительный перенос строки после начального промпта
    }

    List<File> filesToRead = [];

    for (final path in sortedPaths) {
      final entity = FileSystemEntity.typeSync(path, followLinks: false);
      if (entity == FileSystemEntityType.file) {
        if (FileUtils.isLikelyTextFile(path) && !processedFiles.contains(path)) {
          filesToRead.add(File(path));
          processedFiles.add(path);
        }
      } else if (entity == FileSystemEntityType.directory) {
        try {
          final dir = Directory(path);
          final subEntities = dir.listSync(recursive: true, followLinks: false);
          subEntities.sort((a, b) => a.path.compareTo(b.path)); // Сортировка для консистентности

          for (final subEntity in subEntities) {
            if (subEntity is File && FileUtils.isLikelyTextFile(subEntity.path) && !processedFiles.contains(subEntity.path)) {
               filesToRead.add(subEntity);
               processedFiles.add(subEntity.path);
            }
          }
        } catch (e) {
          // Ошибка доступа к поддиректории
          String relativePath = p.relative(path, from: baseDirectoryPath);
          buffer.writeln("$relativePath (ДИРЕКТОРИЯ)");
          buffer.writeln("```");
          buffer.writeln("[ОШИБКА ДОСТУПА: Не удалось прочитать содержимое папки]");
          buffer.writeln("```");
          buffer.writeln();
        }
      }
    }
    
    // Сортировка собранных файлов по пути
    filesToRead.sort((a,b) => a.path.compareTo(b.path));

    for (final file in filesToRead) {
      try {
        String relativePath = p.relative(file.path, from: baseDirectoryPath);
        // Для Windows путей, заменяем \ на / для консистентности с Unix-like выводами
        if (Platform.isWindows) {
            relativePath = relativePath.replaceAll('\\', '/');
        }
        buffer.writeln(relativePath);
        buffer.writeln("```");
        final content = await file.readAsString();
        buffer.writeln(content.trim());
        buffer.writeln("```");
        buffer.writeln();
      } catch (e) {
        String relativePath = p.relative(file.path, from: baseDirectoryPath);
        if (Platform.isWindows) {
            relativePath = relativePath.replaceAll('\\', '/');
        }
        buffer.writeln(relativePath);
        buffer.writeln("```");
        buffer.writeln("[НЕ УДАЛОСЬ ПРОЧИТАТЬ ФАЙЛ: ${e.toString().split('\n').first}]"); // Краткое сообщение об ошибке
        buffer.writeln("```");
        buffer.writeln();
      }
    }

    if (endPrompt.isNotEmpty) {
      // Убираем последний пустой writeln, если он был от файлов, чтобы промпт не был слишком далеко
      String currentContent = buffer.toString();
      if (currentContent.endsWith("\n\n")) {
          buffer.clear();
          buffer.write(currentContent.substring(0, currentContent.length -1));
      } else if (currentContent.endsWith("\n")) {
          // уже хорошо
      } else if (buffer.isNotEmpty) {
          buffer.writeln(); // Добавляем один перенос, если контента не было или он не заканчивался на \n
      }
      
      buffer.writeln(endPrompt.trim());
    }
    
    String result = buffer.toString().trim();
    if (result.isEmpty && selectedPaths.isNotEmpty) {
        return "Не найдено текстовых файлов в выбранных элементах (или они были отфильтрованы/недоступны).";
    }
    if (result.isEmpty && startPrompt.isEmpty && endPrompt.isEmpty){
        return "Выберите файлы/папки и нажмите 'Собрать контент'.";
    }

    return result;
  }
}
```
lib/providers/theme_provider.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themePrefsKey = 'appThemeMode';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themePrefsKey);
    if (themeName == ThemeMode.light.toString()) {
      state = ThemeMode.light;
    } else if (themeName == ThemeMode.dark.toString()) {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefsKey, mode.toString());
  }
}
```

lib/providers/app_state_providers.dart
```dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/models/file_tree_node.dart';
import 'package:file_content_aggregator/services/file_system_service.dart';
import 'package:file_content_aggregator/services/preferences_service.dart';
import 'package:path/path.dart' as p;

// Сервисы
final preferencesServiceProvider = Provider((ref) => PreferencesService());
final fileSystemServiceProvider = Provider((ref) => FileSystemService());

// Основное состояние
final selectedDirectoryProvider = StateProvider<String?>((ref) => null);
final filterTextProvider = StateProvider<String>((ref) => "");

// Состояние дерева файлов
final fileTreeDataProvider = StateNotifierProvider<FileTreeNotifier, AsyncValue<List<FileTreeNode>>>((ref) {
  return FileTreeNotifier(ref);
});

class FileTreeNotifier extends StateNotifier<AsyncValue<List<FileTreeNode>>> {
  final Ref _ref;
  FileTreeNotifier(this._ref) : super(const AsyncValue.data([]));

  Future<void> loadDirectoryTree(String path) async {
    state = const AsyncValue.loading();
    try {
      final nodes = await _ref.read(fileSystemServiceProvider).getDirectoryTree(path, filter: _ref.read(filterTextProvider));
      state = AsyncValue.data(nodes);
      _ref.read(selectedDirectoryProvider.notifier).state = path;
      await _ref.read(preferencesServiceProvider).saveLastDirectory(path);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      // Если ошибка загрузки, сбрасываем выбранную директорию, чтобы UI показал "не выбрано"
      _ref.read(selectedDirectoryProvider.notifier).state = null; 
    }
  }

  Future<void> refreshTree() async {
    final currentPath = _ref.read(selectedDirectoryProvider);
    if (currentPath != null) {
      // Сбрасываем фильтр при обновлении
      _ref.read(filterTextProvider.notifier).state = "";
      // Сбрасываем выделение и раскрытые узлы
      _ref.read(selectedPathsProvider.notifier).clear();
      _ref.read(expandedNodesProvider.notifier).clear();
      await loadDirectoryTree(currentPath);
    }
  }
  
  Future<void> applyFilter(String filter) async {
     final currentPath = _ref.read(selectedDirectoryProvider);
     if (currentPath != null) {
        state = const AsyncValue.loading(); // Показываем индикатор на время фильтрации
        try {
            final nodes = await _ref.read(fileSystemServiceProvider).getDirectoryTree(currentPath, filter: filter);
            state = AsyncValue.data(nodes);
        } catch (e,s) {
            state = AsyncValue.error(e, s);
        }
     }
  }
}

// Выбранные и раскрытые узлы
final selectedPathsProvider = StateNotifierProvider<SelectedPathsNotifier, Set<String>>((ref) {
  return SelectedPathsNotifier();
});

class SelectedPathsNotifier extends StateNotifier<Set<String>> {
  SelectedPathsNotifier() : super({});
  void toggle(String path) {
    if (state.contains(path)) {
      state = {...state}..remove(path);
    } else {
      state = {...state, path};
    }
  }
  void add(String path) {
    state = {...state, path};
  }
  void remove(String path) {
    state = {...state}..remove(path);
  }
  void clear() => state = {};

  void selectAllVisible(List<FileTreeNode> visibleNodes, String currentDirectory) {
    Set<String> pathsToSelect = {};
    
    void DfsCollect(List<FileTreeNode> nodes) {
        for (var node in nodes) {
            // Выбираем все видимые файлы и папки
            // Для простоты, если узел видим, он выбирается.
            // Оригинальный Python-код выбирал только "конечные" файлы,
            // если папка выбрана. Здесь мы выбираем сам узел.
            // Логика агрегации потом разберется, что с этим делать.
            pathsToSelect.add(node.path);
            if (node.isDirectory && node.children.isNotEmpty) {
                DfsCollect(node.children);
            }
        }
    }
    DfsCollect(visibleNodes);
    state = pathsToSelect;
  }
}


final expandedNodesProvider = StateNotifierProvider<ExpandedNodesNotifier, Set<String>>((ref) {
  return ExpandedNodesNotifier();
});

class ExpandedNodesNotifier extends StateNotifier<Set<String>> {
  ExpandedNodesNotifier() : super({});
  void toggle(String path) {
    if (state.contains(path)) {
      state = {...state}..remove(path);
    } else {
      state = {...state, path};
    }
  }
  void clear() => state = {};
}


// Промпты и результат
final startPromptProvider = StateProvider<String>((ref) => "");
final endPromptProvider = StateProvider<String>((ref) => "");

final aggregatedContentProvider = StateNotifierProvider<AggregatedContentNotifier, AsyncValue<String>>((ref) {
    return AggregatedContentNotifier(ref);
});

class AggregatedContentNotifier extends StateNotifier<AsyncValue<String>> {
    final Ref _ref;
    AggregatedContentNotifier(this._ref) : super(const AsyncValue.data(""));

    Future<void> aggregateContent() async {
        final selectedDir = _ref.read(selectedDirectoryProvider);
        final selected = _ref.read(selectedPathsProvider);
        final startPrompt = _ref.read(startPromptProvider);
        final endPrompt = _ref.read(endPromptProvider);

        if (selectedDir == null || selected.isEmpty) {
            state = AsyncValue.data( (startPrompt.isEmpty && endPrompt.isEmpty) ? "Выберите файлы/папки и нажмите 'Собрать контент'." : "Не выбраны файлы для агрегации." );
            return;
        }
        state = const AsyncValue.loading();
        try {
            final content = await _ref.read(fileSystemServiceProvider).aggregateFileContents(
                selected,
                selectedDir,
                startPrompt,
                endPrompt,
            );
            state = AsyncValue.data(content);
        } catch (e, s) {
            state = AsyncValue.error("Ошибка агрегации: $e", s);
        }
    }

    void clearContent() {
        state = const AsyncValue.data("");
    }
}

// Провайдер для начальной загрузки последней директории
final initialDirectoryLoaderProvider = FutureProvider<void>((ref) async {
  final prefsService = ref.read(preferencesServiceProvider);
  final lastDir = await prefsService.getLastDirectory();
  if (lastDir != null && await Directory(lastDir).exists()) {
    // Не используем loadDirectoryTree здесь напрямую, чтобы избежать гонки состояний при запуске
    // Просто устанавливаем selectedDirectoryProvider, HomeScreen позаботится о загрузке дерева
    ref.read(selectedDirectoryProvider.notifier).state = lastDir;
  }
});

// Провайдер для отображения имени выбранной директории
final selectedDirectoryNameProvider = Provider<String>((ref) {
  final path = ref.watch(selectedDirectoryProvider);
  if (path == null) return "Директория не выбрана";
  return "Выбрано: ${p.basename(path)} (${p.dirname(path)})";
});

// Провайдер для доступности кнопок
final canSelectAllProvider = Provider<bool>((ref) {
    final treeState = ref.watch(fileTreeDataProvider);
    return treeState.maybeWhen(
        data: (nodes) => nodes.isNotEmpty,
        orElse: () => false,
    );
});

final canDeselectAllProvider = Provider<bool>((ref) {
    return ref.watch(selectedPathsProvider).isNotEmpty;
});

final canShowContentProvider = Provider<bool>((ref) {
    return ref.watch(selectedPathsProvider).isNotEmpty && ref.watch(selectedDirectoryProvider) != null;
});

final canRefreshProvider = Provider<bool>((ref) {
    return ref.watch(selectedDirectoryProvider) != null;
});

final canCopyProvider = Provider<bool>((ref) {
    final aggregatedContent = ref.watch(aggregatedContentProvider);
    final startPrompt = ref.watch(startPromptProvider);
    final endPrompt = ref.watch(endPromptProvider);
    return aggregatedContent.maybeWhen(data: (data) => data.isNotEmpty, orElse: () => false) || startPrompt.isNotEmpty || endPrompt.isNotEmpty;
});

final canClearAllPromptsAndContentProvider = Provider<bool>((ref) {
    return ref.watch(canCopyProvider); // Логика та же, если есть что копировать, есть что чистить
});

```
lib/widgets/action_bar.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_content_aggregator/providers/theme_provider.dart';
import 'package:clipboard/clipboard.dart'; // Для clipboard.copy

class ActionBar extends ConsumerWidget {
  const ActionBar({super.key});

  void _pickDirectory(BuildContext context, WidgetRef ref) async {
    String? directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Выберите директорию проекта",
    );
    if (directoryPath != null) {
      ref.read(selectedPathsProvider.notifier).clear();
      ref.read(expandedNodesProvider.notifier).clear();
      ref.read(filterTextProvider.notifier).state = "";
      // Очищать ли промпты и контент - по усмотрению. В Python-версии они не очищались при смене папки, если уже были заполнены.
      // ref.read(startPromptProvider.notifier).state = "";
      // ref.read(endPromptProvider.notifier).state = "";
      // ref.read(aggregatedContentProvider.notifier).clearContent();
      await ref.read(fileTreeDataProvider.notifier).loadDirectoryTree(directoryPath);
    }
  }

  void _selectAll(WidgetRef ref) {
    final treeState = ref.read(fileTreeDataProvider);
    final currentDir = ref.read(selectedDirectoryProvider);
    treeState.whenData((nodes) {
      if (currentDir != null) {
        ref.read(selectedPathsProvider.notifier).selectAllVisible(nodes, currentDir);
      }
    });
  }

  void _deselectAll(WidgetRef ref) {
    ref.read(selectedPathsProvider.notifier).clear();
  }

  void _showContent(WidgetRef ref) {
    ref.read(aggregatedContentProvider.notifier).aggregateContent();
  }

  void _refresh(WidgetRef ref) {
     ref.read(aggregatedContentProvider.notifier).clearContent(); // Очищаем перед обновлением
     ref.read(fileTreeDataProvider.notifier).refreshTree();
  }

  void _copyAll(BuildContext context, WidgetRef ref) {
    final startPrompt = ref.read(startPromptProvider);
    final content = ref.read(aggregatedContentProvider).asData?.value ?? "";
    final endPrompt = ref.read(endPromptProvider);

    final parts = <String>[
      if (startPrompt.trim().isNotEmpty) startPrompt.trim(),
      if (content.trim().isNotEmpty) content.trim(),
      if (endPrompt.trim().isNotEmpty) endPrompt.trim(),
    ];
    final fullText = parts.join("\n\n");

    if (fullText.isNotEmpty) {
      FlutterClipboard.copy(fullText).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Текст скопирован в буфер обмена"), duration: Duration(seconds: 2)),
        );
      }).catchError((e) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка копирования: $e"), backgroundColor: Colors.red),
        );
      });
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Нет текста для копирования"), duration: Duration(seconds: 2)),
      );
    }
  }

  void _clearAllFields(WidgetRef ref) {
    ref.read(startPromptProvider.notifier).state = "";
    ref.read(endPromptProvider.notifier).state = "";
    ref.read(aggregatedContentProvider.notifier).clearContent();
    // selectedPaths и filterText не очищаются здесь, это отдельные действия
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isLoadingContent = ref.watch(aggregatedContentProvider).isLoading;
    final isLoadingTree = ref.watch(fileTreeDataProvider).isLoading;

    // Состояния кнопок
    final canSelectAll = ref.watch(canSelectAllProvider);
    final canDeselectAll = ref.watch(canDeselectAllProvider);
    final canShowContent = ref.watch(canShowContentProvider);
    final canRefresh = ref.watch(canRefreshProvider);
    final canCopy = ref.watch(canCopyProvider);
    final canClearAll = ref.watch(canClearAllPromptsAndContentProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
        // color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), // Небольшой фон для панели
      ),
      child: Row(
        children: [
          Tooltip(
            message: "Выбрать директорию [Ctrl+O]",
            child: IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () => _pickDirectory(context, ref),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ref.watch(selectedDirectoryNameProvider),
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: "Выбрать все видимые [Ctrl+A]",
            child: IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: canSelectAll ? () => _selectAll(ref) : null,
            ),
          ),
          Tooltip(
            message: "Снять весь выбор [Esc]",
            child: IconButton(
              icon: const Icon(Icons.deselect),
              onPressed: canDeselectAll ? () => _deselectAll(ref) : null,
            ),
          ),
          const VerticalDivider(indent: 8, endIndent: 8),
          Tooltip(
            message: "Показать/Собрать контент [Enter]",
            child: IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: canShowContent && !isLoadingContent ? () => _showContent(ref) : null,
            ),
          ),
          Tooltip(
            message: "Обновить дерево [Ctrl+R]",
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: canRefresh && !isLoadingTree ? () => _refresh(ref) : null,
            ),
          ),
          Tooltip(
            message: "Копировать всё [Ctrl+C]",
            child: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: canCopy ? () => _copyAll(context, ref) : null,
            ),
          ),
          Tooltip(
            message: "Очистить все поля [Ctrl+X]",
            child: IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: canClearAll ? () => _clearAllFields(ref) : null,
            ),
          ),
          if (isLoadingContent || isLoadingTree)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.0)
              ),
            ),
          const VerticalDivider(indent: 8, endIndent: 8),
          Tooltip(
            message: "Переключить тему",
            child: IconButton(
              icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                ref.read(themeModeProvider.notifier).setThemeMode(
                      themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```
lib/widgets/file_tree_node_widget.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/models/file_tree_node.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';

class FileTreeNodeWidget extends ConsumerWidget {
  final FileTreeNode node;
  final int depth;
  final VoidCallback onToggleExpand; // Передаем колбэк для обновления дерева выше
  final Function(FileTreeNode node) onNodeTap; // Для раскрытия по тапу на имя

  const FileTreeNodeWidget({
    super.key,
    required this.node,
    required this.depth,
    required this.onToggleExpand,
    required this.onNodeTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(selectedPathsProvider.select((selected) => selected.contains(node.path)));
    final isExpanded = ref.watch(expandedNodesProvider.select((expanded) => expanded.contains(node.path)));
    
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onNodeTap(node), // Раскрытие/сворачивание по тапу на строку
          child: Padding(
            padding: EdgeInsets.only(left: depth * 16.0, top: 2, bottom: 2),
            child: Row(
              children: [
                if (node.isDirectory)
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: 20,
                      color: iconColor,
                    ),
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    padding: EdgeInsets.zero,
                    tooltip: isExpanded ? "Свернуть" : "Развернуть",
                    onPressed: () {
                      ref.read(expandedNodesProvider.notifier).toggle(node.path);
                      onToggleExpand(); // Говорим родительскому FileTreeView, что нужно перестроиться
                    },
                  )
                else
                  const SizedBox(width: 24), // Отступ для файлов
                
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    ref.read(selectedPathsProvider.notifier).toggle(node.path);
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Icon(
                  node.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                  size: 18,
                  color: node.isDirectory ? theme.colorScheme.primary : iconColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: node.isDirectory ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (node.isDirectory && isExpanded && node.children.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Отключаем скролл для вложенных списков
            itemCount: node.children.length,
            itemBuilder: (context, index) {
              return FileTreeNodeWidget(
                node: node.children[index],
                depth: depth + 1,
                onToggleExpand: onToggleExpand,
                onNodeTap: onNodeTap,
              );
            },
          ),
      ],
    );
  }
}
```
lib/widgets/file_tree_view.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/models/file_tree_node.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_content_aggregator/widgets/file_tree_node_widget.dart';

class FileTreeView extends ConsumerStatefulWidget {
  const FileTreeView({super.key});

  @override
  ConsumerState<FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends ConsumerState<FileTreeView> {
  // Ключ для принудительного перестроения дерева при изменении expandedNodes
  // Это может быть не самый элегантный способ, но гарантирует обновление
  // при изменении состояния раскрытых узлов, которые хранятся отдельно от самих узлов дерева.
  // Альтернатива - передавать isExpanded напрямую в FileTreeNode и мутировать его,
  // но это усложняет управление состоянием в Riverpod.
  // Здесь мы просто перестраиваем виджет, когда expandedNodes меняются.
  // Или, onToggleExpand в FileTreeNodeWidget может вызывать setState в этом виджете.
  
  // Мы передаем onToggleExpand, который вызовет setState здесь, чтобы дерево перестроилось.
  // Или, если FileTreeNodeWidget сам читает isExpanded из провайдера, то он сам перестроится.
  // FileTreeNodeWidget УЖЕ читает isExpanded из провайдера.
  // Проблема может быть, если ListView.builder не перестраивается.

  void _handleNodeTap(FileTreeNode node) {
    if (node.isDirectory) {
      ref.read(expandedNodesProvider.notifier).toggle(node.path);
      // Не нужен setState, так как FileTreeNodeWidget подписывается на expandedNodesProvider
    }
    // Можно добавить логику для выбора файла по тапу на имя, если чекбокс не удобен
    // ref.read(selectedPathsProvider.notifier).toggle(node.path);
  }
  
  // Используется для перестройки дерева, когда меняется состояние expandedNodes
  // Это гарантирует, что список детей будет корректно отображен/скрыт
  void _forceTreeUIRefresh() {
    if (mounted) {
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    final treeDataAsync = ref.watch(fileTreeDataProvider);
    final selectedDir = ref.watch(selectedDirectoryProvider);

    // Слушаем изменения в expandedNodesProvider, чтобы перестраивать дерево,
    // если структура видимости изменилась (узлы раскрыты/свернуты).
    // FileTreeNodeWidget сам перерисует свою иконку expand/collapse,
    // но этот Listener нужен, чтобы ListView.builder перестроил список детей.
    ref.listen<Set<String>>(expandedNodesProvider, (_, __) {
       _forceTreeUIRefresh(); // Перерисовываем, когда состояние раскрытых узлов меняется
    });


    if (selectedDir == null) {
      return const Center(child: Text("Выберите директорию для отображения дерева файлов.", textAlign: TextAlign.center,));
    }

    return treeDataAsync.when(
      data: (nodes) {
        if (nodes.isEmpty) {
          final filter = ref.read(filterTextProvider);
          if (filter.isNotEmpty) {
            return Center(child: Text("Ничего не найдено по запросу \"$filter\"."));
          }
          return const Center(child: Text("Папка пуста или все файлы отфильтрованы."));
        }
        // Используем ListView.builder для эффективности, если узлов много
        return Scrollbar(
          thumbVisibility: true,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              return FileTreeNodeWidget(
                node: nodes[index],
                depth: 0,
                onToggleExpand: _forceTreeUIRefresh, // Передаем колбэк
                onNodeTap: _handleNodeTap,
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Ошибка загрузки дерева файлов:\n$error",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
```

lib/widgets/file_tree_panel.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_content_aggregator/widgets/file_tree_view.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';

class FileTreePanel extends ConsumerStatefulWidget {
  const FileTreePanel({super.key});

  @override
  ConsumerState<FileTreePanel> createState() => _FileTreePanelState();
}

class _FileTreePanelState extends ConsumerState<FileTreePanel> {
  final _filterController = TextEditingController();
  // Debouncer для фильтра, чтобы не дергать API на каждое нажатие
  // Можно использовать простой Timer или пакет вроде `easy_debounce`
  // В данном случае, для простоты, будем обновлять по окончанию ввода или по кнопке (если бы была)
  // TextField on_changed срабатывает на каждое изменение.

  @override
  void initState() {
    super.initState();
    // Синхронизируем контроллер с состоянием Riverpod, если нужно (например, при hot reload)
    // Но лучше, чтобы Riverpod был единственным источником правды.
    // При инициализации можем установить значение из Riverpod.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) {
    //     _filterController.text = ref.read(filterTextProvider);
    //   }
    // });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем текст в контроллере, если он изменился в провайдере
    // (например, после нажатия "Обновить" где фильтр сбрасывается)
    final currentFilterText = ref.watch(filterTextProvider);
    if (_filterController.text != currentFilterText) {
        WidgetsBinding.instance.addPostFrameCallback((_) { // Чтобы не вызывать setState во время build
            if(mounted) _filterController.text = currentFilterText;
        });
    }
  }


  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String value) {
    ref.read(filterTextProvider.notifier).state = value;
    // Запускаем фильтрацию. FileTreeNotifier должен сам отреагировать на изменение filterTextProvider,
    // но для явного вызова и показа индикатора загрузки, можно вызвать метод.
    ref.read(fileTreeDataProvider.notifier).applyFilter(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Слушаем filterTextProvider, чтобы TextField обновлялся, если фильтр сброшен извне.
    // Это сделано в didChangeDependencies.

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _filterController,
            onChanged: _onFilterChanged, // Обновляем на каждое изменение
            // onSubmitted: _onFilterChanged, // Если хотим только по Enter
            decoration: InputDecoration(
              hintText: "Фильтр дерева (часть имени)...",
              hintStyle: AppConstants.hintStyle.copyWith(color: theme.hintColor),
              prefixIcon: Icon(Icons.search, size: 20, color: theme.iconTheme.color?.withOpacity(0.7)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _filterController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: "Очистить фильтр",
                      onPressed: () {
                        _filterController.clear();
                        _onFilterChanged("");
                      },
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          // Кнопки "Выбрать все" / "Снять выбор" перенесены в ActionBar
          const Expanded(
            child: FileTreeView(),
          ),
        ],
      ),
    );
  }
}
```

lib/widgets/content_panel.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';

class ContentPanel extends ConsumerWidget {
  const ContentPanel({super.key});

  Widget _buildTextFieldWithClear({
    required BuildContext context,
    required String label,
    required String hint,
    required StateProvider<String> provider,
    required WidgetRef ref,
    int minLines = 3,
    int maxLines = 5,
    bool readOnly = false,
    bool isContentDisplay = false,
  }) {
    final controller = TextEditingController(text: ref.watch(provider));
    final theme = Theme.of(context);

    // Слушатель для обновления контроллера, если значение в провайдере изменилось извне
    ref.listen<String>(provider, (_, next) {
      if (controller.text != next) {
        controller.text = next;
        // Перемещаем курсор в конец, если это не readOnly поле и оно активно
        if (!readOnly && (FocusManager.instance.primaryFocus?.context?.widget is EditableText && 
                          (FocusManager.instance.primaryFocus?.context?.widget as EditableText).controller == controller) ) {
           controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
        }
      }
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isContentDisplay) // Не показываем Label для основного поля
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
              child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
            ),
        Stack(
          children: [
            TextField(
              controller: controller,
              readOnly: readOnly,
              onChanged: readOnly ? null : (value) => ref.read(provider.notifier).state = value,
              minLines: minLines,
              maxLines: maxLines,
              scrollPadding: const EdgeInsets.all(20.0),
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppConstants.hintStyle.copyWith(color: theme.hintColor),
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
                fillColor: readOnly 
                    ? theme.colorScheme.surfaceVariant.withOpacity(0.2) 
                    : theme.inputDecorationTheme.fillColor,
              ),
              style: TextStyle(fontSize: readOnly ? 13 : 12.5, fontFamily: readOnly ? 'monospace' : null), // Моноширинный для контента
            ),
            if (!readOnly && controller.text.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: Tooltip(
                  message: "Очистить поле",
                  child: IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      controller.clear();
                      ref.read(provider.notifier).state = "";
                    },
                    splashRadius: 16,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aggregatedContentAsync = ref.watch(aggregatedContentProvider);
    final theme = Theme.of(context);

    // Создаем отдельные контроллеры, чтобы TextField не пересоздавались при каждом билде
    // Но их состояние все равно будет синхронизировано с Riverpod через listen в _buildTextFieldWithClear
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          _buildTextFieldWithClear(
            context: context,
            label: "Начальный промпт:",
            hint: "Добавьте текст перед содержимым файлов...",
            provider: startPromptProvider,
            ref: ref,
            minLines: 2,
            maxLines: 5,
          ),
          const SizedBox(height: 8),
          // Основное поле контента
          Expanded(
            child: aggregatedContentAsync.when(
              data: (content) {
                 // Используем Key, чтобы TextField пересоздавался при смене контента
                 // Иначе controller.text = content не всегда корректно обновляет виджет, если он readOnly
                final contentController = TextEditingController(text: content);
                return TextField(
                  key: ValueKey(content), // Ключ для пересоздания
                  controller: contentController,
                  readOnly: true,
                  minLines: null, // Позволяет занимать всю доступную высоту
                  maxLines: null,
                  expands: true,  // Растягивается
                  textAlignVertical: TextAlignVertical.top, // Текст начинается сверху
                  decoration: InputDecoration(
                    hintText: "Содержимое выбранных файлов появится здесь...",
                    hintStyle: AppConstants.hintStyle.copyWith(color: theme.hintColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                     enabledBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(8),
                       borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.7)),
                     ),
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                    filled: true,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text("Ошибка: $error", style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildTextFieldWithClear(
            context: context,
            label: "Завершающий промпт:",
            hint: "Добавьте текст после содержимого файлов...",
            provider: endPromptProvider,
            ref: ref,
            minLines: 2,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}
```

lib/screens/home_screen.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';
import 'package:file_content_aggregator/widgets/action_bar.dart';
import 'package:file_content_aggregator/widgets/file_tree_panel.dart';
import 'package:file_content_aggregator/widgets/content_panel.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_picker/file_picker.dart'; // Для _pickDirectory в actions
import 'package:clipboard/clipboard.dart';   // Для _copyAll в actions

// --- Intents for Shortcuts ---
class OpenDirectoryIntent extends Intent {}
class SelectAllTreeIntent extends Intent {}
class DeselectAllTreeIntent extends Intent {}
class ShowContentIntent extends Intent {}
class RefreshTreeIntent extends Intent {}
class CopyAllOutputIntent extends Intent {}
class ClearAllFieldsIntent extends Intent {}
class FocusFilterIntent extends Intent {} // Для фокуса на поле фильтра
class SubmitFilterIntent extends Intent {} // Если Enter в фильтре будет что-то делать отдельно

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final FocusNode _mainFocusNode = FocusNode(); // Для общего фокуса и горячих клавиш

  @override
  void initState() {
    super.initState();
    // Загрузка начальной директории при старте
    // initialDirectoryLoaderProvider уже должен был отработать,
    // здесь мы инициируем загрузку дерева, если директория была установлена.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialDir = ref.read(selectedDirectoryProvider);
      if (initialDir != null && initialDir.isNotEmpty) {
        // Проверяем, не загружается ли уже дерево
        if (ref.read(fileTreeDataProvider) is! AsyncLoading) {
           ref.read(fileTreeDataProvider.notifier).loadDirectoryTree(initialDir);
        }
      }
       // Запрашиваем фокус для горячих клавиш
      FocusScope.of(context).requestFocus(_mainFocusNode);
    });
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
    super.dispose();
  }

  // --- Actions for Shortcuts ---
  void _handleOpenDirectory() async {
    String? directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Выберите директорию проекта",
    );
    if (directoryPath != null) {
      ref.read(selectedPathsProvider.notifier).clear();
      ref.read(expandedNodesProvider.notifier).clear();
      ref.read(filterTextProvider.notifier).state = "";
      await ref.read(fileTreeDataProvider.notifier).loadDirectoryTree(directoryPath);
    }
  }

  void _handleSelectAllTree() {
    if (ref.read(canSelectAllProvider)) {
      final treeState = ref.read(fileTreeDataProvider);
      final currentDir = ref.read(selectedDirectoryProvider);
      treeState.whenData((nodes) {
        if (currentDir != null) {
          ref.read(selectedPathsProvider.notifier).selectAllVisible(nodes, currentDir);
        }
      });
    }
  }
  
  void _handleDeselectAllTree() {
    if (ref.read(canDeselectAllProvider)) {
      ref.read(selectedPathsProvider.notifier).clear();
    }
  }

  void _handleShowContent() {
    if (ref.read(canShowContentProvider) && !ref.read(aggregatedContentProvider).isLoading) {
      ref.read(aggregatedContentProvider.notifier).aggregateContent();
    }
  }

  void _handleRefreshTree() {
    if (ref.read(canRefreshProvider) && !ref.read(fileTreeDataProvider).isLoading) {
      ref.read(aggregatedContentProvider.notifier).clearContent();
      ref.read(fileTreeDataProvider.notifier).refreshTree();
    }
  }

  void _handleCopyAllOutput() {
     if (ref.read(canCopyProvider)) {
        final startPrompt = ref.read(startPromptProvider);
        final content = ref.read(aggregatedContentProvider).asData?.value ?? "";
        final endPrompt = ref.read(endPromptProvider);

        final parts = <String>[
          if (startPrompt.trim().isNotEmpty) startPrompt.trim(),
          if (content.trim().isNotEmpty) content.trim(),
          if (endPrompt.trim().isNotEmpty) endPrompt.trim(),
        ];
        final fullText = parts.join("\n\n");

        if (fullText.isNotEmpty) {
          FlutterClipboard.copy(fullText).then((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Текст скопирован в буфер обмена"), duration: Duration(seconds: 2)),
            );
          });
        }
     }
  }
  
  void _handleClearAllFields() {
    if (ref.read(canClearAllPromptsAndContentProvider)) {
        ref.read(startPromptProvider.notifier).state = "";
        ref.read(endPromptProvider.notifier).state = "";
        ref.read(aggregatedContentProvider.notifier).clearContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Показываем индикатор загрузки, если initialDirectoryLoaderProvider еще не завершился
    final initialLoading = ref.watch(initialDirectoryLoaderProvider);
    if (initialLoading is AsyncLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (initialLoading is AsyncError) {
       return Scaffold(
        body: Center(child: Text("Ошибка инициализации: ${initialLoading.error}")),
      );
    }


    // Определяем карту ярлыков и действий
    final shortcuts = <ShortcutActivator, Intent>{
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyO): OpenDirectoryIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA): SelectAllTreeIntent(),
      LogicalKeySet(LogicalKeyboardKey.escape): DeselectAllTreeIntent(),
      LogicalKeySet(LogicalKeyboardKey.enter): ShowContentIntent(),
      // Для некоторых систем Enter может быть NumLock Enter. Добавим оба.
      LogicalKeySet(LogicalKeyboardKey.numpadEnter): ShowContentIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): RefreshTreeIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): CopyAllOutputIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX): ClearAllFieldsIntent(),
      // LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL): FocusFilterIntent(), // Пример для фокуса
    };

    final actions = <Type, Action<Intent>>{
      OpenDirectoryIntent: CallbackAction<OpenDirectoryIntent>(onInvoke: (_) => _handleOpenDirectory()),
      SelectAllTreeIntent: CallbackAction<SelectAllTreeIntent>(onInvoke: (_) => _handleSelectAllTree()),
      DeselectAllTreeIntent: CallbackAction<DeselectAllTreeIntent>(onInvoke: (_) => _handleDeselectAllTree()),
      ShowContentIntent: CallbackAction<ShowContentIntent>(onInvoke: (_) => _handleShowContent()),
      RefreshTreeIntent: CallbackAction<RefreshTreeIntent>(onInvoke: (_) => _handleRefreshTree()),
      CopyAllOutputIntent: CallbackAction<CopyAllOutputIntent>(onInvoke: (_) => _handleCopyAllOutput()),
      ClearAllFieldsIntent: CallbackAction<ClearAllFieldsIntent>(onInvoke: (_) => _handleClearAllFields()),
      // FocusFilterIntent: CallbackAction<FocusFilterIntent>(onInvoke: (_) => _focusFilterField()),
    };


    return FocusableActionDetector( // Обертка для горячих клавиш
      autofocus: true, // Автоматически фокусируемся для работы шорткатов
      focusNode: _mainFocusNode,
      shortcuts: shortcuts,
      actions: actions,
      child: Scaffold(
        appBar: PreferredSize( // Используем PreferredSize для ActionBar в AppBar
          preferredSize: const Size.fromHeight(kToolbarHeight), // Стандартная высота AppBar
          child: ActionBar(),
        ),
        body: Column(
          children: [
            // ActionBar(), // Перемещен в AppBar
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    flex: AppConstants.leftPanelFlex,
                    child: FileTreePanel(),
                  ),
                  // Вертикальный разделитель можно убрать, если граница панели достаточна
                  // const VerticalDivider(width: 1, thickness: 1),
                  const Expanded(
                    flex: AppConstants.rightPanelFlex,
                    child: ContentPanel(),
                  ),
                ],
              ),
            ),
            // Status bar (optional)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("File Content Aggregator v${AppConstants.appVersion}", style: Theme.of(context).textTheme.bodySmall),
                  // Можно добавить количество выбранных файлов/папок
                  Consumer(builder: (context, ref, _) {
                    final selectedCount = ref.watch(selectedPathsProvider).length;
                    return Text(selectedCount > 0 ? "Выбрано: $selectedCount" : "", style: Theme.of(context).textTheme.bodySmall);
                  }),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
```