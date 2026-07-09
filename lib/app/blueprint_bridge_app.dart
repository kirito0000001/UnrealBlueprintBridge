import 'package:flutter/material.dart';

import 'bridge_scroll_behavior.dart';
import '../features/workspace/workspace_shell.dart';

class BlueprintBridgeApp extends StatelessWidget {
  const BlueprintBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '虚幻：蓝图连结',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const BridgeScrollBehavior(),
      theme: ThemeData(
        fontFamily: 'Microsoft YaHei UI',
        scaffoldBackgroundColor: const Color(0xFFF3F8FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scrollbarTheme: ScrollbarThemeData(
          radius: const Radius.circular(999),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.dragged) ||
                states.contains(WidgetState.hovered)) {
              return const Color(0xFF2563EB).withValues(alpha: 0.72);
            }

            return const Color(0xFF93C5FD).withValues(alpha: 0.46);
          }),
          trackColor: WidgetStateProperty.all(
            const Color(0xFFDBEAFE).withValues(alpha: 0.42),
          ),
          thickness: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.dragged) ||
                states.contains(WidgetState.hovered)) {
              return 8;
            }

            return 6;
          }),
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Microsoft YaHei UI',
        scaffoldBackgroundColor: const Color(0xFF07111F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF60A5FA),
          brightness: Brightness.dark,
        ),
        scrollbarTheme: ScrollbarThemeData(
          radius: const Radius.circular(999),
          thumbColor: WidgetStateProperty.all(
            const Color(0xFF60A5FA).withValues(alpha: 0.62),
          ),
          thickness: WidgetStateProperty.all(6),
        ),
        useMaterial3: true,
      ),
      home: const WorkspaceShell(),
    );
  }
}
