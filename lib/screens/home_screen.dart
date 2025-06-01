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