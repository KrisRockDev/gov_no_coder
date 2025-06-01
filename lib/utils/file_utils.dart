import 'dart:convert'; // <--- ДОБАВЛЕН ДЛЯ SystemEncoding
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
      // Условие pathParts.indexOf(part) < pathParts.length -1 означает, что это не последний элемент (т.е. не сам файл)
      if (part.startsWith('.') && part.length > 1 && pathParts.indexOf(part) < pathParts.length - 1) {
        // Если это директория и она скрытая
        String potentialDirPath = p.joinAll(pathParts.sublist(0, pathParts.indexOf(part) + 1));
        if (Directory(potentialDirPath).existsSync()) {
          // Дополнительно проверяем, не является ли это специальным файлом типа .gitignore
          // которые мы *хотим* включить, даже если они в скрытой папке (хотя они обычно в корне)
          bool isKnownHiddenTextFile = AppConstants.textExtensions.any((ext) => p.basename(filePath).toLowerCase() == ext || p.basename(filePath).toLowerCase().endsWith(ext));
          if (!isKnownHiddenTextFile) {
            return false;
          }
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
        // Используем const SystemEncoding()
        // ignore: unused_local_variable
        final content = file.readAsStringSync(encoding: const SystemEncoding()); // <--- ИСПРАВЛЕНО ЗДЕСЬ
        // Проверка на нулевые байты или непечатаемые символы может быть добавлена здесь
        // Для простоты, если чтение удалось без ошибок, считаем текстовым
        return true;
      } catch (e) {
        // Если ошибка чтения (например, бинарный файл или неверная кодировка), то это не текстовый файл
        return false;
      }
    }
    return false;
  }
}