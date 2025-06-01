import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_content_aggregator/widgets/file_tree_view.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';

class FileTreePanel extends ConsumerStatefulWidget {
  const FileTreePanel({super.key});

  @override
  ConsumerState<FileTreePanel> createState() => _FileTreePanelState();
}

class _FileTreePanelState extends ConsumerState<FileTreePanel> {
  final _filterController = TextEditingController();
  // Debouncer для фильтра, чтобы не дергать API на каждое нажатие
  // Можно использовать простой Timer или пакет вроде `easy_debounce`
  // В данном случае, для простоты, будем обновлять по окончанию ввода или по кнопке (если бы была)
  // TextField on_changed срабатывает на каждое изменение.

  @override
  void initState() {
    super.initState();
    // Синхронизируем контроллер с состоянием Riverpod, если нужно (например, при hot reload)
    // Но лучше, чтобы Riverpod был единственным источником правды.
    // При инициализации можем установить значение из Riverpod.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) {
    //     _filterController.text = ref.read(filterTextProvider);
    //   }
    // });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем текст в контроллере, если он изменился в провайдере
    // (например, после нажатия "Обновить" где фильтр сбрасывается)
    final currentFilterText = ref.watch(filterTextProvider);
    if (_filterController.text != currentFilterText) {
        WidgetsBinding.instance.addPostFrameCallback((_) { // Чтобы не вызывать setState во время build
            if(mounted) _filterController.text = currentFilterText;
        });
    }
  }


  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String value) {
    ref.read(filterTextProvider.notifier).state = value;
    // Запускаем фильтрацию. FileTreeNotifier должен сам отреагировать на изменение filterTextProvider,
    // но для явного вызова и показа индикатора загрузки, можно вызвать метод.
    ref.read(fileTreeDataProvider.notifier).applyFilter(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Слушаем filterTextProvider, чтобы TextField обновлялся, если фильтр сброшен извне.
    // Это сделано в didChangeDependencies.

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _filterController,
            onChanged: _onFilterChanged, // Обновляем на каждое изменение
            // onSubmitted: _onFilterChanged, // Если хотим только по Enter
            decoration: InputDecoration(
              hintText: "Фильтр дерева (часть имени)...",
              hintStyle: AppConstants.hintStyle.copyWith(color: theme.hintColor),
              prefixIcon: Icon(Icons.search, size: 20, color: theme.iconTheme.color?.withOpacity(0.7)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _filterController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: "Очистить фильтр",
                      onPressed: () {
                        _filterController.clear();
                        _onFilterChanged("");
                      },
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          // Кнопки "Выбрать все" / "Снять выбор" перенесены в ActionBar
          const Expanded(
            child: FileTreeView(),
          ),
        ],
      ),
    );
  }
}