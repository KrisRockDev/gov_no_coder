import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/models/file_tree_node.dart';
import 'package:file_content_aggregator/services/file_system_service.dart';
import 'package:file_content_aggregator/services/preferences_service.dart';
import 'package:path/path.dart' as p;
import 'package:file_content_aggregator/constants/app_constants.dart';

final preferencesServiceProvider = Provider((ref) => PreferencesService());
final fileSystemServiceProvider = Provider((ref) => FileSystemService());

final selectedDirectoryProvider = StateProvider<String?>((ref) => null);
final filterTextProvider = StateProvider<String>((ref) => "");

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
      _ref.read(selectedDirectoryProvider.notifier).state = null;
    }
  }

  Future<void> refreshTree() async {
    final currentPath = _ref.read(selectedDirectoryProvider);
    if (currentPath != null) {
      _ref.read(filterTextProvider.notifier).state = "";
      _ref.read(selectedPathsProvider.notifier).clear();
      _ref.read(expandedNodesProvider.notifier).clear();
      await loadDirectoryTree(currentPath);
    }
  }

  Future<void> applyFilter(String filter) async {
     final currentPath = _ref.read(selectedDirectoryProvider);
     if (currentPath != null) {
        state = const AsyncValue.loading();
        try {
            final nodes = await _ref.read(fileSystemServiceProvider).getDirectoryTree(currentPath, filter: filter);
            state = AsyncValue.data(nodes);
        } catch (e,s) {
            state = AsyncValue.error(e, s);
        }
     }
  }
}

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
  void add(String path) => state = {...state, path};
  void remove(String path) => state = {...state}..remove(path);
  void clear() => state = {};

  void selectAllVisible(List<FileTreeNode> visibleNodes, String currentDirectory) {
    Set<String> pathsToSelect = {};
    void dfsCollect(List<FileTreeNode> nodes) {
        for (var node in nodes) {
            pathsToSelect.add(node.path);
            if (node.isDirectory && node.children.isNotEmpty) {
                dfsCollect(node.children);
            }
        }
    }
    dfsCollect(visibleNodes);
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

final startPromptProvider = StateProvider<String>((ref) => "");
// Для endPromptProvider, мы больше не устанавливаем defaultUpdateSystemPrompt здесь,
// так как он теперь будет загружаться из файла prompt_finish.txt (если есть) или останется пустым.
// Системный промпт для обновления файлов будет браться из AppConstants.defaultUpdateSystemPrompt напрямую при копировании, если поле endPrompt пусто.
final endPromptProvider = StateProvider<String>((ref) => ""); // Теперь по умолчанию пустой
final filesToUpdateInputProvider = StateProvider<String>((ref) => "");

final aggregatedContentProvider = StateNotifierProvider<AggregatedContentNotifier, AsyncValue<String>>((ref) {
    return AggregatedContentNotifier(ref);
});

class AggregatedContentNotifier extends StateNotifier<AsyncValue<String>> {
    final Ref _ref;
    AggregatedContentNotifier(this._ref) : super(const AsyncValue.data(""));

    Future<void> aggregateContent() async {
        final selectedDir = _ref.read(selectedDirectoryProvider);
        final selected = _ref.read(selectedPathsProvider);
        
        String startPromptFromFile = "";
        String endPromptFromFile = "";

        if (selectedDir != null) {
            startPromptFromFile = await _ref.read(fileSystemServiceProvider).readPromptFile(selectedDir, AppConstants.startPromptFileName);
            endPromptFromFile = await _ref.read(fileSystemServiceProvider).readPromptFile(selectedDir, AppConstants.endPromptFileName);
            
            // Если файл prompt_start.txt найден и его содержимое не пусто, оно используется
            // Иначе, если поле было непустым (введено пользователем), оно сохраняется
            final currentStartPromptInField = _ref.read(startPromptProvider);
            if (startPromptFromFile.isNotEmpty) {
                 _ref.read(startPromptProvider.notifier).state = startPromptFromFile;
            } else if (currentStartPromptInField.isEmpty) {
                 // Если файл пуст и поле пусто, оставляем поле пустым
                 _ref.read(startPromptProvider.notifier).state = "";
            }
            // То же для конечного промпта, но с учетом, что defaultUpdateSystemPrompt больше не используется как дефолт для этого поля
            final currentEndPromptInField = _ref.read(endPromptProvider);
             if (endPromptFromFile.isNotEmpty) {
                 _ref.read(endPromptProvider.notifier).state = endPromptFromFile;
            } else if (currentEndPromptInField.isEmpty) {
                  _ref.read(endPromptProvider.notifier).state = "";
            } else if (currentEndPromptInField == AppConstants.defaultUpdateSystemPrompt && endPromptFromFile.isEmpty){
                // Если в поле был системный промпт по умолчанию, а файл пуст, то очищаем поле
                 _ref.read(endPromptProvider.notifier).state = "";
            }

        }
        final currentStartPrompt = _ref.read(startPromptProvider);

        if (selectedDir == null || selected.isEmpty) {
            state = AsyncValue.data(currentStartPrompt.isEmpty ? "Выберите файлы/папки и нажмите 'Собрать контент'." : "Не выбраны файлы для агрегации.");
            return;
        }
        state = const AsyncValue.loading();
        try {
            final content = await _ref.read(fileSystemServiceProvider).aggregateFileContents(
                selected,
                selectedDir,
                currentStartPrompt,
                "", // Конечный промпт не передаем сюда для агрегации основного контента
            );
            state = AsyncValue.data(content);
        } catch (e, s) {
            state = AsyncValue.error("Ошибка агрегации: $e", s);
        }
    }
    void clearContent() => state = const AsyncValue.data("");
}

final updateFilesStatusProvider = StateNotifierProvider<UpdateFilesStatusNotifier, AsyncValue<String>>((ref) {
  return UpdateFilesStatusNotifier(ref);
});

class UpdateFilesStatusNotifier extends StateNotifier<AsyncValue<String>> {
  final Ref _ref;
  UpdateFilesStatusNotifier(this._ref) : super(const AsyncValue.data(""));

  Future<void> updateProjectFiles() async {
    final rootDir = _ref.read(selectedDirectoryProvider);
    final updateData = _ref.read(filesToUpdateInputProvider);

    if (rootDir == null || rootDir.isEmpty) {
      state = AsyncValue.error("Корневая директория проекта не выбрана.", StackTrace.current);
      return;
    }
    if (updateData.isEmpty) {
      state = AsyncValue.error("Нет данных для обновления файлов.", StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final resultMessage = await _ref.read(fileSystemServiceProvider).updateFilesFromMarkdown(rootDir, updateData);
      state = AsyncValue.data(resultMessage);
      await _ref.read(fileTreeDataProvider.notifier).refreshTree();
    } catch (e, s) {
      state = AsyncValue.error("Ошибка обновления файлов: $e", s);
    }
  }
  void clearStatus() => state = const AsyncValue.data("");
}

final initialDirectoryLoaderProvider = FutureProvider<void>((ref) async {
  final prefsService = ref.read(preferencesServiceProvider);
  final lastDir = await prefsService.getLastDirectory();
  if (lastDir != null && await Directory(lastDir).exists()) {
    ref.read(selectedDirectoryProvider.notifier).state = lastDir;
  }
});

final selectedDirectoryNameProvider = Provider<String>((ref) {
  final path = ref.watch(selectedDirectoryProvider);
  if (path == null || path.isEmpty) return "Директория не выбрана"; // Добавлена проверка на пустой путь
  return path;
});

final canSelectAllProvider = Provider<bool>((ref) {
    final treeState = ref.watch(fileTreeDataProvider);
    return treeState.maybeWhen(data: (nodes) => nodes.isNotEmpty, orElse: () => false);
});

final canDeselectAllProvider = Provider<bool>((ref) => ref.watch(selectedPathsProvider).isNotEmpty);
final canShowContentProvider = Provider<bool>((ref) {
  final selectedDir = ref.watch(selectedDirectoryProvider);
  return ref.watch(selectedPathsProvider).isNotEmpty && selectedDir != null;
});
final canRefreshProvider = Provider<bool>((ref) => ref.watch(selectedDirectoryProvider) != null);

final canCopyProvider = Provider<bool>((ref) {
    final aggregatedContent = ref.watch(aggregatedContentProvider);
    final startPrompt = ref.watch(startPromptProvider);
    final endPromptVal = ref.watch(endPromptProvider);
    final String actualEndPrompt = endPromptVal.trim().isEmpty ? AppConstants.defaultUpdateSystemPrompt : endPromptVal;

    return aggregatedContent.maybeWhen(data: (data) => data.trim().isNotEmpty, orElse: () => false) ||
           startPrompt.trim().isNotEmpty ||
           actualEndPrompt.trim().isNotEmpty; // Проверяем актуальный endPrompt для копирования
});

final canClearAllPromptsAndContentProvider = Provider<bool>((ref) {
    final aggregatedContent = ref.watch(aggregatedContentProvider);
    final startPrompt = ref.watch(startPromptProvider);
    final endPromptVal = ref.watch(endPromptProvider);
    final updateInput = ref.watch(filesToUpdateInputProvider);
    return aggregatedContent.maybeWhen(data: (data) => data.trim().isNotEmpty, orElse: () => false) ||
           startPrompt.trim().isNotEmpty ||
           endPromptVal.trim().isNotEmpty || // Если поле endPrompt не пустое, его можно очистить
           updateInput.trim().isNotEmpty;
});

final canUpdateProjectFilesProvider = Provider<bool>((ref) {
  return ref.watch(filesToUpdateInputProvider).isNotEmpty && ref.watch(selectedDirectoryProvider) != null;
});
