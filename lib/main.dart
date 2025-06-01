import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_content_aggregator/screens/home_screen.dart';
import 'package:file_content_aggregator/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Важно для shared_preferences и других плагинов
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'File Content Aggregator',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.blue.withOpacity(0.05),
        ),
        tooltipTheme: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 500),
          textStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onInverseSurface),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
         inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.blue.withOpacity(0.1),
        ),
        tooltipTheme: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 500),
          textStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onInverseSurface),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      themeMode: themeMode,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}