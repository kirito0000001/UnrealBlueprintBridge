import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/features/editor/canvas/graph_node_style.dart';
import 'package:unreal_blueprint_bridge/features/editor/catalog/unreal_node_catalog.dart';

void main() {
  test('GraphNodeStyle colors custom event nodes red like Unreal', () {
    expect(GraphNodeStyle.headerColor('CustomEvent'), const Color(0xFFB91C1C));
    expect(GraphNodeStyle.headerColor('Event'), const Color(0xFFB91C1C));
  });

  test('GraphNodeStyle colors custom event call nodes blue like Unreal', () {
    expect(GraphNodeStyle.headerColor('EventCall'), const Color(0xFF2563EB));
  });

  test('GraphNodeStyle colors object and Actor pins blue like Unreal', () {
    expect(GraphNodeStyle.pinColor('object'), const Color(0xFF2563EB));
    expect(GraphNodeStyle.pinColor('Actor'), const Color(0xFF2563EB));
    expect(GraphNodeStyle.pinColor('exec'), const Color(0xFFFFFFFF));
  });

  test('GraphNodeStyle colors pure function calls green', () {
    expect(
      GraphNodeStyle.functionHeaderColor(pure: false),
      const Color(0xFF2563EB),
    );
    expect(
      GraphNodeStyle.functionHeaderColor(pure: true),
      const Color(0xFF16A34A),
    );
  });

  test('GraphNodeStyle covers common Unreal pin data types', () {
    expect(GraphNodeStyle.pinColor('bool'), const Color(0xFFDC2626));
    expect(GraphNodeStyle.pinColor('int'), const Color(0xFF22C55E));
    expect(GraphNodeStyle.pinColor('float'), const Color(0xFF22C55E));
    expect(GraphNodeStyle.pinColor('string'), const Color(0xFFD946EF));
    expect(GraphNodeStyle.pinColor('text'), const Color(0xFFD946EF));
    expect(GraphNodeStyle.pinColor('vector'), const Color(0xFFEAB308));
    expect(GraphNodeStyle.pinColor('rotator'), const Color(0xFFA855F7));
    expect(GraphNodeStyle.pinColor('transform'), const Color(0xFFF97316));
    expect(GraphNodeStyle.pinColor('class'), const Color(0xFF7C3AED));
    expect(GraphNodeStyle.pinColor('array'), const Color(0xFF06B6D4));
  });

  test('GraphNodeStyle reuses pin colors for variable type colors', () {
    final boolTint = GraphNodeStyle.variableTint('bool', alpha: 0.18);

    expect(GraphNodeStyle.variableColor('bool'), const Color(0xFFDC2626));
    expect(GraphNodeStyle.variableColor('Actor'), const Color(0xFF2563EB));
    expect(boolTint.r, closeTo(0xDC / 255, 0.001));
    expect(boolTint.g, closeTo(0x26 / 255, 0.001));
    expect(boolTint.b, closeTo(0x26 / 255, 0.001));
    expect(boolTint.a, closeTo(0.18, 0.001));
  });

  test(
    'Unreal catalog includes core flow, variable, container, object nodes',
    () {
      final requiredIds = [
        'gate',
        'do_once',
        'multi_gate',
        'switch_on_enum',
        'select',
        'get_bool_variable',
        'set_bool_variable',
        'get_vector_variable',
        'set_transform_variable',
        'array_get',
        'array_add',
        'map_find',
        'map_add',
        'set_add',
        'spawn_actor_from_class',
        'cast_to_actor',
        'create_widget',
        'switch_has_authority',
      ];

      for (final id in requiredIds) {
        expect(UnrealNodeCatalog.find(id), isNotNull, reason: id);
      }
    },
  );

  test('Unreal catalog keeps Custom Event as a custom node type', () {
    final template = UnrealNodeCatalog.find('custom_event');

    expect(template?.title, 'Custom Event');
    expect(template?.nodeType, 'CustomEvent');
  });
}
