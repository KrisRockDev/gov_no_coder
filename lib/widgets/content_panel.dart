import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/providers/app_state_providers.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';

class ContentPanel extends ConsumerStatefulWidget {
  const ContentPanel({super.key});

  @override
  ConsumerState<ContentPanel> createState() => _ContentPanelState();
}

class _ContentPanelState extends ConsumerState<ContentPanel> {
  late TextEditingController _startPromptController;
  late TextEditingController _endPromptController;
  // Контроллер для contentDisplay обновляется через ValueKey, так что его можно оставить локальным в build

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры начальными значениями из провайдеров
    _startPromptController = TextEditingController(text: ref.read(startPromptProvider));
    _endPromptController = TextEditingController(text: ref.read(endPromptProvider));

    // Добавляем слушатели для обновления состояния провайдеров при изменении текста в контроллерах
    _startPromptController.addListener(() {
      // Чтобы избежать рекурсивных обновлений, проверяем, отличается ли значение
      if (ref.read(startPromptProvider) != _startPromptController.text) {
        ref.read(startPromptProvider.notifier).state = _startPromptController.text;
      }
    });
    _endPromptController.addListener(() {
      if (ref.read(endPromptProvider) != _endPromptController.text) {
        ref.read(endPromptProvider.notifier).state = _endPromptController.text;
      }
    });
  }

  @override
  void didUpdateWidget(ContentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Этот метод не обязателен, если мы обновляем контроллеры через ref.watch и ref.listen,
    // но может быть полезен для сложной логики.
    // В данном случае, синхронизация при изменении провайдера извне будет в `build` через `ref.listen`.
  }


  @override
  void dispose() {
    _startPromptController.dispose();
    _endPromptController.dispose();
    super.dispose();
  }

  Widget _buildTextFieldWithClear({
    required BuildContext context,
    required String label,
    required String hint,
    required TextEditingController controller, // Принимаем контроллер
    required StateProvider<String> provider, // Для очистки и начального значения (хотя начальное уже в initState)
    required WidgetRef ref,
    int minLines = 3,
    int maxLines = 5,
  }) {
    final theme = Theme.of(context);

    // Слушаем изменения в провайдере, чтобы обновить контроллер, если значение изменилось ИЗВНЕ
    // (например, кнопкой "Очистить все поля")
    ref.listen<String>(provider, (_, next) {
      if (controller.text != next) {
        // Сохраняем текущую позицию курсора
        final currentSelection = controller.selection;
        controller.text = next;
        // Пытаемся восстановить позицию курсора, если текст не пустой
        if (next.isNotEmpty && currentSelection.start < next.length && currentSelection.end < next.length) {
          try {
            controller.selection = currentSelection;
          } catch (e) {
            // Если старая позиция невалидна (например, текст стал короче), ставим в конец
            controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
          }
        } else {
          controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
          child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
        ),
        Stack(
          children: [
            TextField(
              controller: controller, // Используем переданный контроллер
              // onChanged больше не нужен здесь для обновления провайдера, т.к. есть listener у контроллера
              minLines: minLines,
              maxLines: maxLines,
              scrollPadding: const EdgeInsets.all(20.0),
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppConstants.hintStyle.copyWith(color: theme.hintColor),
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
                fillColor: theme.inputDecorationTheme.fillColor,
              ),
              style: const TextStyle(fontSize: 12.5),
            ),
            // Кнопка очистки все еще может зависеть от текста в контроллере,
            // но для ее отображения/скрытия нужно будет перерисовывать виджет,
            // когда текст контроллера меняется. Это можно сделать, обернув Stack
            // в ValueListenableBuilder, слушающий контроллер, или просто всегда показывать кнопку
            // и делать ее disabled если текст пуст, но это менее красиво.
            // Либо, так как мы в StatefulWidget, можем использовать controller.addListener и вызывать setState.
            // Проще всего - ориентироваться на состояние провайдера для отображения кнопки очистки.
            Consumer(builder: (context, ref, _) { // Используем Consumer для доступа к актуальному состоянию провайдера
              final currentText = ref.watch(provider);
              if (currentText.isNotEmpty) {
                return Positioned(
                  top: 0,
                  right: 0,
                  child: Tooltip(
                    message: "Очистить поле",
                    child: IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        // Очищаем и контроллер, и провайдер
                        controller.clear();
                        // ref.read(provider.notifier).state = ""; // Это вызовется listener'ом контроллера
                      },
                      splashRadius: 16,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final aggregatedContentAsync = ref.watch(aggregatedContentProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          _buildTextFieldWithClear(
            context: context,
            label: "Начальный промпт:",
            hint: "Добавьте текст перед содержимым файлов...",
            controller: _startPromptController, // Передаем контроллер
            provider: startPromptProvider, // Для кнопки очистки и синхронизации
            ref: ref,
            minLines: 2,
            maxLines: 5,
          ),
          const SizedBox(height: 8),
          // Основное поле контента
          Expanded(
            child: aggregatedContentAsync.when(
              data: (content) {
                final contentController = TextEditingController(text: content);
                return TextField(
                  key: ValueKey(content),
                  controller: contentController,
                  readOnly: true,
                  minLines: null,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: "Содержимое выбранных файлов появится здесь...",
                    hintStyle: AppConstants.hintStyle.copyWith(color: theme.hintColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.7)),
                    ),
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                    filled: true,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text("Ошибка: $error", style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildTextFieldWithClear(
            context: context,
            label: "Завершающий промпт:",
            hint: "Добавьте текст после содержимого файлов...",
            controller: _endPromptController, // Передаем контроллер
            provider: endPromptProvider, // Для кнопки очистки и синхронизации
            ref: ref,
            minLines: 2,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}