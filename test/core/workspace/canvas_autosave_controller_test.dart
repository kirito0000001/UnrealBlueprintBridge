import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_document.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_viewport.dart';
import 'package:unreal_blueprint_bridge/core/workspace/canvas_autosave_controller.dart';

void main() {
  test(
    'CanvasAutosaveController saves only the last rapid document change',
    () async {
      final savedTitles = <String>[];
      final controller = CanvasAutosaveController<GraphDocument>(
        delay: const Duration(milliseconds: 40),
        save: (document) async => savedTitles.add(document.graph.title),
      );
      addTearDown(controller.dispose);

      controller.schedule(_document('First drag frame'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.schedule(_document('Second drag frame'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.schedule(_document('Final drag frame'));

      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(savedTitles, ['Final drag frame']);
    },
  );

  test(
    'CanvasAutosaveController flushes pending changes immediately',
    () async {
      final savedTitles = <String>[];
      final controller = CanvasAutosaveController<GraphDocument>(
        delay: const Duration(minutes: 1),
        save: (document) async => savedTitles.add(document.graph.title),
      );
      addTearDown(controller.dispose);

      controller.schedule(_document('Pending canvas'));
      await controller.flush();

      expect(savedTitles, ['Pending canvas']);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(savedTitles, ['Pending canvas']);
    },
  );
}

GraphDocument _document(String title) {
  final now = DateTime.parse('2026-07-07T12:00:00+08:00');

  return GraphDocument(
    schemaVersion: GraphDocument.currentSchemaVersion,
    graph: GraphMetadata(
      id: title.toLowerCase().replaceAll(' ', '_'),
      title: title,
      description: '',
      createdAt: now,
      updatedAt: now,
      viewport: const GraphViewport(offsetX: 0, offsetY: 0, zoom: 1),
    ),
    nodes: const [],
    links: const [],
  );
}
