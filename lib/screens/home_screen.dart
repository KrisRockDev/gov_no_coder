import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';
import 'package:file_content_aggregator/widgets/action_bar.dart';
import 'package:file_content_aggregator/widgets/file_tree_panel.dart';
import 'package:file_content_aggregator/widgets/content_panel.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:clipboard/clipboard.dart';

// --- Intents for Shortcuts ---
class OpenDirectoryIntent extends Intent {}
class SelectAllTreeIntent extends Intent {}
class DeselectAllTreeIntent extends Intent {}
class ShowContentIntent extends Intent {} // Будет Ctrl+Enter
class RefreshTreeIntent extends Intent {}
class CopyAllOutputIntent extends Intent {} // Будет Ctrl+Shift+C
class ClearAllFieldsIntent extends Intent {}
class UpdateProjectFilesIntent extends Intent {}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final FocusNode _mainFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialDir = ref.read(selectedDirectoryProvider);
      if (initialDir != null && initialDir.isNotEmpty) {
        if (ref.read(fileTreeDataProvider) is! AsyncLoading) {
          ref.read(fileTreeDataProvider.notifier).loadDirectoryTree(initialDir);
        }
      }
      FocusScope.of(context).requestFocus(_mainFocusNode);
    });
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
    super.dispose();
  }

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
      ref.read(endPromptProvider.notifier).state = AppConstants.defaultUpdateSystemPrompt;
      ref.read(filesToUpdateInputProvider.notifier).state = "";
      ref.read(aggregatedContentProvider.notifier).clearContent();
    }
  }

  void _handleUpdateProjectFiles() {
    if (ref.read(canUpdateProjectFilesProvider) && !ref.read(updateFilesStatusProvider).isLoading) {
      final statusNotifier = ref.read(updateFilesStatusProvider.notifier);
      statusNotifier.updateProjectFiles().then((_) {
        final result = ref.read(updateFilesStatusProvider);
        final currentContext = context;
        if (currentContext.mounted) {
          result.when(
            data: (message) {
              if (message.isNotEmpty) {
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
                );
              }
            },
            loading: () {},
            error: (error, _) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(content: Text("Ошибка: $error"), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
              );
            },
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialLoading = ref.watch(initialDirectoryLoaderProvider);
    if (initialLoading is AsyncLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (initialLoading is AsyncError) {
      return Scaffold(body: Center(child: Text("Ошибка инициализации: ${initialLoading.error}")));
    }

    final shortcuts = <ShortcutActivator, Intent>{
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyO): OpenDirectoryIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA): SelectAllTreeIntent(),
      LogicalKeySet(LogicalKeyboardKey.escape): DeselectAllTreeIntent(),
      // Измененные горячие клавиши
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): ShowContentIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.numpadEnter): ShowContentIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyC): CopyAllOutputIntent(),
      // Остальные
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): RefreshTreeIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX): ClearAllFieldsIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU): UpdateProjectFilesIntent(),
    };

    final actions = <Type, Action<Intent>>{
      OpenDirectoryIntent: CallbackAction<OpenDirectoryIntent>(onInvoke: (_) => _handleOpenDirectory()),
      SelectAllTreeIntent: CallbackAction<SelectAllTreeIntent>(onInvoke: (_) => _handleSelectAllTree()),
      DeselectAllTreeIntent: CallbackAction<DeselectAllTreeIntent>(onInvoke: (_) => _handleDeselectAllTree()),
      ShowContentIntent: CallbackAction<ShowContentIntent>(onInvoke: (_) => _handleShowContent()),
      RefreshTreeIntent: CallbackAction<RefreshTreeIntent>(onInvoke: (_) => _handleRefreshTree()),
      CopyAllOutputIntent: CallbackAction<CopyAllOutputIntent>(onInvoke: (_) => _handleCopyAllOutput()),
      ClearAllFieldsIntent: CallbackAction<ClearAllFieldsIntent>(onInvoke: (_) => _handleClearAllFields()),
      UpdateProjectFilesIntent: CallbackAction<UpdateProjectFilesIntent>(onInvoke: (_) => _handleUpdateProjectFiles()),
    };

    return FocusableActionDetector(
      autofocus: true,
      focusNode: _mainFocusNode,
      shortcuts: shortcuts,
      actions: actions,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ActionBar(),
        ),
        body: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    flex: AppConstants.leftPanelFlex,
                    child: FileTreePanel(),
                  ),
                  const Expanded(
                    flex: AppConstants.rightPanelFlex,
                    child: ContentPanel(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("File Content Aggregator v${AppConstants.appVersion}", style: Theme.of(context).textTheme.bodySmall),
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