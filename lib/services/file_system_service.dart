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

    List<String> getAllFilesAndDirs(String rootPath) {
      List<String> paths = [];
      try {
        Directory root = Directory(rootPath);
        if (!root.existsSync()) return paths;

        root.listSync(recursive: true, followLinks: false).forEach((entity) {
          final entityName = p.basename(entity.path);
          bool shouldIgnore = AppConstants.ignoreDirs.contains(entityName.toLowerCase());

          List<String> parts = p.split(entity.path);
          for (int i = 0; i < parts.length -1; i++) {
            if (parts[i].startsWith('.') && parts[i].length > 1) {
              if (AppConstants.ignoreDirs.contains(parts[i].toLowerCase())) {
                shouldIgnore = true;
                break;
              }
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
                if(!isTextFileInHiddenDir){
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
          String current = path;
          while (p.dirname(current) != p.dirname(rootPath) && current != rootPath) {
            current = p.dirname(current);
            if (current == rootPath || current == p.dirname(rootPath)) break;
            if (allPaths.contains(current)) {
              visible.add(current);
            } else {
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
              if(foundValidParent) break;
            }
          }
        }
      }
      if (visible.isNotEmpty && allPaths.contains(rootPath)) {
        visible.add(rootPath);
      }
      return visible;
    }

    final visiblePaths = getVisiblePaths(directoryPath, filter);

    List<FileTreeNode> buildFilteredTree(Directory currentDir, Set<String> visible) {
      List<FileTreeNode> nodes = [];
      try {
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
          } else if (entity is File) {
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

    if (filter.isNotEmpty && visiblePaths.isEmpty) {
      return [];
    }
    return buildFilteredTree(dir, visiblePaths);
  }

  Future<String> aggregateFileContents(
      Set<String> selectedPaths,
      String baseDirectoryPath,
      String startPrompt,
      String endPrompt, // Этот параметр больше не используется для формирования основного контента
      ) async {
    final buffer = StringBuffer();
    final List<String> sortedPaths = selectedPaths.toList()..sort();
    final Set<String> processedFiles = {};

    if (startPrompt.trim().isNotEmpty) {
      buffer.writeln(startPrompt.trim());
      buffer.writeln();
    }

    List<File> filesToRead = [];

    for (final path in sortedPaths) {
      final entityType = FileSystemEntity.typeSync(path, followLinks: false);
      if (entityType == FileSystemEntityType.file) {
        if (FileUtils.isLikelyTextFile(path) && !processedFiles.contains(path)) {
          filesToRead.add(File(path));
          processedFiles.add(path);
        }
      } else if (entityType == FileSystemEntityType.directory) {
        try {
          final dir = Directory(path);
          final subEntities = dir.listSync(recursive: true, followLinks: false);
          subEntities.sort((a, b) => a.path.compareTo(b.path));

          for (final subEntity in subEntities) {
            if (subEntity is File && FileUtils.isLikelyTextFile(subEntity.path) && !processedFiles.contains(subEntity.path)) {
              filesToRead.add(subEntity);
              processedFiles.add(subEntity.path);
            }
          }
        } catch (e) {
          String relativePath = p.relative(path, from: baseDirectoryPath);
          buffer.writeln("$relativePath (ДИРЕКТОРИЯ)");
          buffer.writeln("```");
          buffer.writeln("[ОШИБКА ДОСТУПА: Не удалось прочитать содержимое папки]");
          buffer.writeln("```");
          buffer.writeln();
        }
      }
    }

    filesToRead.sort((a,b) => a.path.compareTo(b.path));

    for (final file in filesToRead) {
      try {
        String relativePath = p.relative(file.path, from: baseDirectoryPath);
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
        buffer.writeln("[НЕ УДАЛОСЬ ПРОЧИТАТЬ ФАЙЛ: ${e.toString().split('\n').first}]");
        buffer.writeln("```");
        buffer.writeln();
      }
    }

    String result = buffer.toString().trimRight();

    if (result.isEmpty && selectedPaths.isNotEmpty && startPrompt.trim().isEmpty) {
      return "Не найдено текстовых файлов в выбранных элементах (или они были отфильтрованы/недоступны).";
    }
    if (result.isEmpty && startPrompt.trim().isEmpty) {
      return "Выберите файлы/папки и нажмите 'Собрать контент'.";
    }

    return result;
  }

  Future<String> updateFilesFromMarkdown(String projectRootPath, String markdownData) async {
    String normalizedData = markdownData.replaceAll('\r\n', '\n');
    normalizedData = normalizedData.replaceAll(RegExp(r'```[a-zA-Z]+(\r?\n)'), '```\n');

    final List<Map<String, String>> fileUpdates = [];
    final RegExp blockPattern = RegExp(
      r'^(.*?)\n```\n(.*?)\n```',
      multiLine: true,
      dotAll: true,
    );

    Iterable<RegExpMatch> matches = blockPattern.allMatches(normalizedData);

    int successfulUpdates = 0;
    int failedUpdates = 0;
    List<String> errorMessages = [];
    String currentFilePathRelativeForError = ""; // Для более точного сообщения об ошибке

    bool mainPatternMatched = false;
    Iterator<RegExpMatch>? matchIterator = matches.isNotEmpty ? matches.iterator : null;

    if (matchIterator != null && matchIterator.moveNext()) {
      mainPatternMatched = true;
      // Сбрасываем итератор для прохода по всем совпадениям
      matches = blockPattern.allMatches(normalizedData); // Переполучаем, т.к. итератор был использован
      for (final match in matches) {
        String filePathRelative = match.group(1)!.trim();
        currentFilePathRelativeForError = filePathRelative; // Сохраняем для возможной ошибки
        String fileContent = match.group(2)!;

        if (filePathRelative.isEmpty) continue;
        fileUpdates.add({'path': filePathRelative, 'content': fileContent});
      }
    }

    if (!mainPatternMatched && normalizedData.trim().isNotEmpty) {
      final parts = normalizedData.split(RegExp(r'\n```\n?'));
      if (parts.length >= 2) {
        for (int i = 0; i < parts.length; i += 2) {
          if (i + 1 < parts.length) {
            String filePathRelative = parts[i].trim();
            currentFilePathRelativeForError = filePathRelative;
            String fileContent = parts[i+1];

            if (fileContent.trimRight().endsWith('```')) {
              fileContent = fileContent.substring(0, fileContent.lastIndexOf('```'));
            }

            if (filePathRelative.isEmpty) continue;
            fileUpdates.add({'path': filePathRelative, 'content': fileContent});
          } else if (parts[i].trim().isNotEmpty && parts.length % 2 != 0 && i == parts.length -1){
            currentFilePathRelativeForError = parts[i].trim();
            errorMessages.add("Ошибка формата: Обнаружен путь '$currentFilePathRelativeForError' без соответствующего блока кода.");
            failedUpdates++;
          }
        }
      }
    }

    if (fileUpdates.isEmpty && normalizedData.trim().isNotEmpty) {
      return "Ошибка: Не удалось извлечь данные для обновления файлов. Убедитесь, что формат соответствует:\nпуть/к/файлу\n```\nкод файла\n```";
    }
    if (fileUpdates.isEmpty && normalizedData.trim().isEmpty) {
      return "Нет данных для обновления.";
    }

    for (var update in fileUpdates) {
      String relativePath = update['path']!;
      String content = update['content']!;
      currentFilePathRelativeForError = relativePath; // Обновляем для текущей операции

      relativePath = relativePath.replaceAll('\\', '/');
      if (relativePath.startsWith('/')) {
        relativePath = relativePath.substring(1);
      }
      String absolutePath = p.join(projectRootPath, relativePath);

      try {
        String? directoryPath = p.dirname(absolutePath);
        if (directoryPath.isNotEmpty && !await Directory(directoryPath).exists()) {
          await Directory(directoryPath).create(recursive: true);
        }
        File file = File(absolutePath);
        String contentToWrite = content;
        if (content.isNotEmpty && !content.endsWith('\n')) {
          contentToWrite += '\n';
        }

        await file.writeAsString(contentToWrite, flush: true);
        successfulUpdates++;
      } catch (e) {
        failedUpdates++;
        // Используем currentFilePathRelativeForError здесь, так как оно будет более актуальным
        errorMessages.add("Ошибка записи файла $currentFilePathRelativeForError: $e");
      }
    }

    String message = "Обновление завершено. Успешно: $successfulUpdates. Ошибок: $failedUpdates.";
    if (errorMessages.isNotEmpty) {
      message += "\nДетали ошибок:\n${errorMessages.join('\n')}";
    }
    return message;
  }
}