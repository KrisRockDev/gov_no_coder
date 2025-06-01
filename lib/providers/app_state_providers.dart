import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/models/file_tree_node.dart';
import 'package:file_content_aggregator/services/file_system_service.dart';
import 'package:file_content_aggregator/services/preferences_service.dart';
import 'package:path/path.dart' as p;
import 'package:file_content_aggregator/constants/app_constants.dart'; // Для defaultUpdateSystemPrompt

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

// Промпты, результат и поле для обновления файлов
final startPromptProvider = StateProvider<String>((ref) => "");
final endPromptProvider = StateProvider<String>((ref) => AppConstants.defaultUpdateSystemPrompt); // <--- Устанавливаем промпт по умолчанию
final filesToUpdateInputProvider = StateProvider<String>((ref) => ""); // <--- Новое поле

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
        final endPromptVal = _ref.read(endPromptProvider); // Читаем значение, а не сам провайдер

        if (selectedDir == null || selected.isEmpty) {
            state = AsyncValue.data( (startPrompt.isEmpty && endPromptVal.isEmpty) ? "Выберите файлы/папки и нажмите 'Собрать контент'." : "Не выбраны файлы для агрегации." );
            return;
        }
        state = const AsyncValue.loading();
        try {
            final content = await _ref.read(fileSystemServiceProvider).aggregateFileContents(
                selected,
                selectedDir,
                startPrompt,
                endPromptVal,
            );
            state = AsyncValue.data(content);
        } catch (e, s) {
            state = AsyncValue.error("Ошибка агрегации: $e", s);
        }
    }
    void clearContent() => state = const AsyncValue.data("");
}

// Провайдер для статуса обновления файлов
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
      // После успешного обновления, обновим дерево файлов, чтобы видеть изменения
      await _ref.read(fileTreeDataProvider.notifier).refreshTree();
    } catch (e, s) {
      state = AsyncValue.error("Ошибка обновления файлов: $e", s);
    }
  }
  void clearStatus() => state = const AsyncValue.data("");
}


// Провайдер для начальной загрузки последней директории
final initialDirectoryLoaderProvider = FutureProvider<void>((ref) async {
  final prefsService = ref.read(preferencesServiceProvider);
  final lastDir = await prefsService.getLastDirectory();
  if (lastDir != null && await Directory(lastDir).exists()) {
    ref.read(selectedDirectoryProvider.notifier).state = lastDir;
  }
});

// Провайдер для отображения имени выбранной директории
final selectedDirectoryNameProvider = Provider<String>((ref) {
  final path = ref.watch(selectedDirectoryProvider);
  if (path == null) return "Директория не выбрана";
  // Более короткое отображение пути
  String basePath = p.basename(path);
  String parentPath = p.basename(p.dirname(path));
  if (parentPath.isEmpty || parentPath == '.' || parentPath == p.separator) return "Выбрано: $basePath";
  return "Выбрано: ...${p.separator}$parentPath${p.separator}$basePath";
});

// Провайдер для доступности кнопок
final canSelectAllProvider = Provider<bool>((ref) {
    final treeState = ref.watch(fileTreeDataProvider);
    return treeState.maybeWhen(data: (nodes) => nodes.isNotEmpty, orElse: () => false);
});

final canDeselectAllProvider = Provider<bool>((ref) => ref.watch(selectedPathsProvider).isNotEmpty);
final canShowContentProvider = Provider<bool>((ref) => ref.watch(selectedPathsProvider).isNotEmpty && ref.watch(selectedDirectoryProvider) != null);
final canRefreshProvider = Provider<bool>((ref) => ref.watch(selectedDirectoryProvider) != null);

final canCopyProvider = Provider<bool>((ref) {
    final aggregatedContent = ref.watch(aggregatedContentProvider);
    final startPrompt = ref.watch(startPromptProvider);
    final endPromptVal = ref.watch(endPromptProvider);
    return aggregatedContent.maybeWhen(data: (data) => data.isNotEmpty, orElse: () => false) || startPrompt.isNotEmpty || endPromptVal.isNotEmpty;
});

final canClearAllPromptsAndContentProvider = Provider<bool>((ref) => ref.watch(canCopyProvider));

// Провайдер для кнопки обновления файлов проекта
final canUpdateProjectFilesProvider = Provider<bool>((ref) {
  return ref.watch(filesToUpdateInputProvider).isNotEmpty && ref.watch(selectedDirectoryProvider) != null;
});