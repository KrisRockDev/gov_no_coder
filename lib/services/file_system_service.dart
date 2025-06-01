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