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