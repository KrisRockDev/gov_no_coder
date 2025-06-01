import 'dart:convert'; 
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_content_aggregator/constants/app_constants.dart';

class FileUtils {
  static bool isLikelyTextFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final fileName = p.basename(filePath).toLowerCase();
    // Явно исключаем файлы промптов из категории "likely text file" для основного сканирования
    if (fileName == AppConstants.startPromptFileName || fileName == AppConstants.endPromptFileName) {
      return false;
    }

    List<String> pathParts = p.split(filePath);
    for (String part in pathParts) {
      // Используем AppConstants.ignoreDirsAndFiles
      if (AppConstants.ignoreDirsAndFiles.contains(part.toLowerCase())) {
        return false;
      }
      if (part.startsWith('.') && part.length > 1 && pathParts.indexOf(part) < pathParts.length - 1) {
        String potentialDirPath = p.joinAll(pathParts.sublist(0, pathParts.indexOf(part) + 1));
        if (Directory(potentialDirPath).existsSync()) {
          bool isKnownHiddenTextFile = AppConstants.textExtensions.any((ext) => p.basename(filePath).toLowerCase() == ext || p.basename(filePath).toLowerCase().endsWith(ext));
          if (!isKnownHiddenTextFile) {
            return false;
          }
        }
      }
    }

    final extension = p.extension(filePath).toLowerCase();
    final nameLower = p.basename(filePath).toLowerCase(); // Уже есть как fileName

    if (AppConstants.textExtensions.contains(nameLower) || AppConstants.textExtensions.contains(extension)) {
      return true;
    }

    if (extension.isEmpty || !AppConstants.textExtensions.contains(extension)) {
      try {
        // ignore: unused_local_variable
        final content = file.readAsStringSync(encoding: const SystemEncoding()); 
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }
}