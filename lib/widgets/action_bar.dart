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