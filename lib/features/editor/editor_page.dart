import 'package:flutter/material.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({super.key});

  static const _nodeTypes = <String>[
    'Generic',
    'Event',
    'Function',
    'Branch',
    'Variable',
    'Comment',
    'Note',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _EditorToolbar(colorScheme: colorScheme),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  if (compact) {
                    return const _CompactEditorShell();
                  }

                  return const _DesktopEditorShell();
                },
              ),
            ),
            const _EditorStatusBar(),
          ],
        ),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined),
          const SizedBox(width: 12),
          Text('虚幻：蓝图连结', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.folder_open),
            label: const Text('Open'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _DesktopEditorShell extends StatelessWidget {
  const _DesktopEditorShell();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 220, child: _NodePalettePanel()),
        Expanded(child: _CanvasPlaceholder()),
        SizedBox(width: 280, child: _InspectorPanel()),
      ],
    );
  }
}

class _CompactEditorShell extends StatelessWidget {
  const _CompactEditorShell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _CanvasPlaceholder()),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Node'),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.tune),
                    label: const Text('Inspector'),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.hub_outlined),
                    label: const Text('Link'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NodePalettePanel extends StatelessWidget {
  const _NodePalettePanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Node Palette', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          for (final nodeType in EditorPage._nodeTypes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(onPressed: () {}, child: Text(nodeType)),
            ),
        ],
      ),
    );
  }
}

class _CanvasPlaceholder extends StatelessWidget {
  const _CanvasPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomPaint(
      painter: _GridPainter(color: colorScheme.outlineVariant),
      child: Center(
        child: Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.84),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hub_outlined, size: 42),
                SizedBox(height: 12),
                Text('Node canvas foundation'),
                SizedBox(height: 6),
                Text('Drag, zoom, pins, and links will be implemented here.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    const step = 24.0;

    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inspector', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          const Text('Selection'),
          const SizedBox(height: 6),
          Text(
            'No node selected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Graph JSON'),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: const Center(child: Text('Preview pending')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorStatusBar extends StatelessWidget {
  const _EditorStatusBar();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Text('Ready', style: Theme.of(context).textTheme.labelMedium),
          const Spacer(),
          Text(
            'Nodes 0 · Links 0 · Zoom 100%',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
