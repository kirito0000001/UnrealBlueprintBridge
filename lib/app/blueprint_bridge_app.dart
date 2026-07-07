import 'package:flutter/material.dart';

import '../features/editor/editor_page.dart';

class BlueprintBridgeApp extends StatelessWidget {
  const BlueprintBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '虚幻：蓝图连结',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF246BFD),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7EA4FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}
