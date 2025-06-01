import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/models/file_tree_node.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_content_aggregator/widgets/file_tree_node_widget.dart';

class FileTreeView extends ConsumerStatefulWidget {
  const FileTreeView({super.key});

  @override
  ConsumerState<FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends ConsumerState<FileTreeView> {
  // Ключ для принудительного перестроения дерева при изменении expandedNodes
  // Это может быть не самый элегантный способ, но гарантирует обновление
  // при изменении состояния раскрытых узлов, которые хранятся отдельно от самих узлов дерева.
  // Альтернатива - передавать isExpanded напрямую в FileTreeNode и мутировать его,
  // но это усложняет управление состоянием в Riverpod.
  // Здесь мы просто перестраиваем виджет, когда expandedNodes меняются.
  // Или, onToggleExpand в FileTreeNodeWidget может вызывать setState в этом виджете.
  
  // Мы передаем onToggleExpand, который вызовет setState здесь, чтобы дерево перестроилось.
  // Или, если FileTreeNodeWidget сам читает isExpanded из провайдера, то он сам перестроится.
  // FileTreeNodeWidget УЖЕ читает isExpanded из провайдера.
  // Проблема может быть, если ListView.builder не перестраивается.

  void _handleNodeTap(FileTreeNode node) {
    if (node.isDirectory) {
      ref.read(expandedNodesProvider.notifier).toggle(node.path);
      // Не нужен setState, так как FileTreeNodeWidget подписывается на expandedNodesProvider
    }
    // Можно добавить логику для выбора файла по тапу на имя, если чекбокс не удобен
    // ref.read(selectedPathsProvider.notifier).toggle(node.path);
  }
  
  // Используется для перестройки дерева, когда меняется состояние expandedNodes
  // Это гарантирует, что список детей будет корректно отображен/скрыт
  void _forceTreeUIRefresh() {
    if (mounted) {
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    final treeDataAsync = ref.watch(fileTreeDataProvider);
    final selectedDir = ref.watch(selectedDirectoryProvider);

    // Слушаем изменения в expandedNodesProvider, чтобы перестраивать дерево,
    // если структура видимости изменилась (узлы раскрыты/свернуты).
    // FileTreeNodeWidget сам перерисует свою иконку expand/collapse,
    // но этот Listener нужен, чтобы ListView.builder перестроил список детей.
    ref.listen<Set<String>>(expandedNodesProvider, (_, __) {
       _forceTreeUIRefresh(); // Перерисовываем, когда состояние раскрытых узлов меняется
    });


    if (selectedDir == null) {
      return const Center(child: Text("Выберите директорию для отображения дерева файлов.", textAlign: TextAlign.center,));
    }

    return treeDataAsync.when(
      data: (nodes) {
        if (nodes.isEmpty) {
          final filter = ref.read(filterTextProvider);
          if (filter.isNotEmpty) {
            return Center(child: Text("Ничего не найдено по запросу \"$filter\"."));
          }
          return const Center(child: Text("Папка пуста или все файлы отфильтрованы."));
        }
        // Используем ListView.builder для эффективности, если узлов много
        return Scrollbar(
          thumbVisibility: true,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              return FileTreeNodeWidget(
                node: nodes[index],
                depth: 0,
                onToggleExpand: _forceTreeUIRefresh, // Передаем колбэк
                onNodeTap: _handleNodeTap,
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Ошибка загрузки дерева файлов:\n$error",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}