import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_content_aggregator/providers/theme_provider.dart';
import 'package:clipboard/clipboard.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';


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
    if (ref.read(canShowContentProvider) && !ref.read(aggregatedContentProvider).isLoading) {
      ref.read(aggregatedContentProvider.notifier).aggregateContent();
    }
  }

  void _refresh(WidgetRef ref) {
    ref.read(aggregatedContentProvider.notifier).clearContent();
    ref.read(fileTreeDataProvider.notifier).refreshTree();
  }

  void _copyAll(BuildContext context, WidgetRef ref) {
    final startPrompt = ref.read(startPromptProvider);
    final content = ref.read(aggregatedContentProvider).asData?.value ?? "";
    final endPromptValue = ref.read(endPromptProvider);
    final String actualEndPrompt = endPromptValue.trim().isEmpty ? AppConstants.defaultUpdateSystemPrompt : endPromptValue;

    final parts = <String>[
      if (startPrompt.trim().isNotEmpty) startPrompt.trim(),
      if (content.trim().isNotEmpty) content.trim(),
      if (actualEndPrompt.trim().isNotEmpty) actualEndPrompt.trim(),
    ];
    final fullText = parts.join("\n\n").trim();

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
    ref.read(endPromptProvider.notifier).state = ""; // Очищаем, т.к. defaultUpdateSystemPrompt больше не дефолт для поля
    ref.read(filesToUpdateInputProvider.notifier).state = "";
    ref.read(aggregatedContentProvider.notifier).clearContent();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isLoadingContent = ref.watch(aggregatedContentProvider).isLoading;
    final isLoadingTree = ref.watch(fileTreeDataProvider).isLoading;
    final isLoadingUpdate = ref.watch(updateFilesStatusProvider).isLoading;

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
              softWrap: false, // Чтобы не переносился на новую строку
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
            message: "Показать/Собрать контент [Ctrl+Enter]",
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
            message: "Копировать всё [Ctrl+Shift+C]",
            child: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: canCopy ? () => _copyAll(context, ref) : null,
            ),
          ),
          Tooltip(
            message: "Очистить все поля", // Убрали [Ctrl+Shift+X] из подсказки
            child: IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: canClearAll ? () => _clearAllFields(ref) : null,
            ),
          ),
          if (isLoadingContent || isLoadingTree || isLoadingUpdate)
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
