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
  late TextEditingController _filesToUpdateController;

  @override
  void initState() {
    super.initState();
    _startPromptController = TextEditingController(text: ref.read(startPromptProvider));
    _endPromptController = TextEditingController(text: ref.read(endPromptProvider));
    _filesToUpdateController = TextEditingController(text: ref.read(filesToUpdateInputProvider));

    _startPromptController.addListener(() {
      if (ref.read(startPromptProvider) != _startPromptController.text) {
        ref.read(startPromptProvider.notifier).state = _startPromptController.text;
      }
    });
    _endPromptController.addListener(() {
      if (ref.read(endPromptProvider) != _endPromptController.text) {
        ref.read(endPromptProvider.notifier).state = _endPromptController.text;
      }
    });
    _filesToUpdateController.addListener(() {
      if (ref.read(filesToUpdateInputProvider) != _filesToUpdateController.text) {
        ref.read(filesToUpdateInputProvider.notifier).state = _filesToUpdateController.text;
      }
    });
  }

  @override
  void dispose() {
    _startPromptController.dispose();
    _endPromptController.dispose();
    _filesToUpdateController.dispose();
    super.dispose();
  }

  Widget _buildTextFieldWithClear({
    required BuildContext context,
    String? label,
    required String hint,
    required TextEditingController controller,
    required StateProvider<String> provider,
    required WidgetRef ref,
    int minLines = 3,
    int? maxLines = 5,
    bool expands = false,
    TextStyle? textStyle,
    String? fontFamily,
    bool readOnlyField = false,
  }) {
    final theme = Theme.of(context);

    ref.listen<String>(provider, (_, next) {
      if (controller.text != next) {
        final currentSelection = controller.selection;
        controller.text = next;
        if (next.isNotEmpty) {
          try {
            controller.selection = TextSelection.fromPosition(
                TextPosition(offset: currentSelection.baseOffset.clamp(0, next.length))
            );
          } catch (e) {
            controller.selection = TextSelection.fromPosition(TextPosition(offset: next.length));
          }
        } else {
          controller.selection = TextSelection.collapsed(offset: 0);
        }
      }
    });

    Widget textField = Stack(
      children: [
        TextField(
          controller: controller,
          readOnly: readOnlyField,
          minLines: expands ? null : minLines,
          maxLines: expands ? null : maxLines,
          expands: expands,
          textAlignVertical: expands ? TextAlignVertical.top : null,
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
            fillColor: readOnlyField
                ? theme.colorScheme.surfaceVariant.withOpacity(0.2)
                : theme.inputDecorationTheme.fillColor,
            filled: true,
          ),
          style: textStyle ?? TextStyle(fontSize: 12.5, fontFamily: fontFamily),
        ),
        Consumer(builder: (context, ref, _) {
          final currentText = ref.watch(provider);
          if (currentText.isNotEmpty && !readOnlyField) {
            return Positioned(
              top: 0,
              right: 0,
              child: Tooltip(
                message: "Очистить поле",
                child: IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    controller.clear();
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: expands ? MainAxisSize.max : MainAxisSize.min, // Если expands, то max
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
            child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
          ),
        if (expands) Expanded(child: textField) else textField,
      ],
    );
  }


  void _handleUpdateFiles(BuildContext context, WidgetRef ref) async {
    final statusNotifier = ref.read(updateFilesStatusProvider.notifier);
    await statusNotifier.updateProjectFiles();

    final result = ref.read(updateFilesStatusProvider);
    final currentContext = context;
    if (!currentContext.mounted) return;

    result.when(
      data: (message) {
        if (message.isNotEmpty) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
          );
        }
      },
      loading: () { },
      error: (error, stackTrace) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text("Ошибка: $error"), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final aggregatedContentAsync = ref.watch(aggregatedContentProvider);
    final updateStatusAsync = ref.watch(updateFilesStatusProvider);
    final theme = Theme.of(context);
    final canUpdateFiles = ref.watch(canUpdateProjectFilesProvider);

    // Увеличенные min/max lines для промптов
    const promptMinLines = 3; // Было 2
    const promptMaxLines = 5; // Было 3

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Начальный и конечный промпты теперь занимают всю ширину, если они видимы
          // и размещаются над разделенным полем
          _buildTextFieldWithClear(
            context: context,
            label: "Начальный промпт:",
            hint: "Добавьте текст перед содержимым файлов...",
            controller: _startPromptController,
            provider: startPromptProvider,
            ref: ref,
            minLines: promptMinLines,
            maxLines: promptMaxLines,
            // expands: false, // Не растягиваем эти поля, они фиксированной высоты
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                        child: Text("Агрегированный контент:", style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                      ),
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
                                hintText: "Содержимое выбранных файлов...",
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                        child: Text("Данные для обновления файлов:", style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                      ),
                      Expanded(
                        child: _buildTextFieldWithClear(
                          context: context,
                          hint: "Вставьте сюда ответ для обновления файлов...\nФормат:\nпуть/к/файлу1\n```\nкод...\n```\nпуть/к/файлу2\n```\nкод...\n```",
                          controller: _filesToUpdateController,
                          provider: filesToUpdateInputProvider,
                          ref: ref,
                          minLines: 10,
                          maxLines: null,
                          expands: true,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: updateStatusAsync.isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.system_update_alt),
                          label: Text(updateStatusAsync.isLoading ? "Обновление..." : "Обновить файлы проекта"),
                          onPressed: canUpdateFiles && !updateStatusAsync.isLoading
                              ? () => _handleUpdateFiles(context, ref)
                              : null,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 13)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildTextFieldWithClear(
            context: context,
            label: "Завершающий промпт (системный):",
            hint: "Инструкции для ИИ по формату обновления файлов...",
            controller: _endPromptController,
            provider: endPromptProvider,
            ref: ref,
            minLines: promptMinLines, // Увеличенные строки
            maxLines: promptMaxLines, // Увеличенные строки
            // expands: false, // Не растягиваем
          ),
        ],
      ),
    );
  }
}