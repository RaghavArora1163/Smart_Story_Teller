import 'package:flutter/material.dart';
import 'screens/story_maker_page.dart';

void main() {
  runApp(const StoryApp());
}

class StoryApp extends StatelessWidget {
  const StoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(primary: Color(0xFF3B82F6)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: Color(0xFF3B82F6)),
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Story Teller',
      theme: theme,
      home: const StoryMakerPage(),
    );
  }
}
