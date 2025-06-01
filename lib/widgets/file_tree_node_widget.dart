import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/models/file_tree_node.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';

class FileTreeNodeWidget extends ConsumerWidget {
  final FileTreeNode node;
  final int depth;
  final VoidCallback onToggleExpand; // Передаем колбэк для обновления дерева выше
  final Function(FileTreeNode node) onNodeTap; // Для раскрытия по тапу на имя

  const FileTreeNodeWidget({
    super.key,
    required this.node,
    required this.depth,
    required this.onToggleExpand,
    required this.onNodeTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(selectedPathsProvider.select((selected) => selected.contains(node.path)));
    final isExpanded = ref.watch(expandedNodesProvider.select((expanded) => expanded.contains(node.path)));
    
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onNodeTap(node), // Раскрытие/сворачивание по тапу на строку
          child: Padding(
            padding: EdgeInsets.only(left: depth * 16.0, top: 2, bottom: 2),
            child: Row(
              children: [
                if (node.isDirectory)
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: 20,
                      color: iconColor,
                    ),
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    padding: EdgeInsets.zero,
                    tooltip: isExpanded ? "Свернуть" : "Развернуть",
                    onPressed: () {
                      ref.read(expandedNodesProvider.notifier).toggle(node.path);
                      onToggleExpand(); // Говорим родительскому FileTreeView, что нужно перестроиться
                    },
                  )
                else
                  const SizedBox(width: 24), // Отступ для файлов
                
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    ref.read(selectedPathsProvider.notifier).toggle(node.path);
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Icon(
                  node.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                  size: 18,
                  color: node.isDirectory ? theme.colorScheme.primary : iconColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: node.isDirectory ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (node.isDirectory && isExpanded && node.children.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Отключаем скролл для вложенных списков
            itemCount: node.children.length,
            itemBuilder: (context, index) {
              return FileTreeNodeWidget(
                node: node.children[index],
                depth: depth + 1,
                onToggleExpand: onToggleExpand,
                onNodeTap: onNodeTap,
              );
            },
          ),
      ],
    );
  }
}