import 'package:flutter/material.dart';

class GraphNodeStyle {
  const GraphNodeStyle._();

  static Color headerColor(String nodeType) {
    return switch (nodeType) {
      'CustomEvent' || 'Event' => const Color(0xFFB91C1C),
      'EventCall' => const Color(0xFF2563EB),
      'Function' || 'FunctionCall' => const Color(0xFF2563EB),
      'Branch' || 'FlowControl' => const Color(0xFF334155),
      'Variable' || 'VariableGet' || 'VariableSet' => const Color(0xFF15803D),
      'Latent' => const Color(0xFF0F766E),
      'Container' => const Color(0xFF0891B2),
      'Object' || 'Class' || 'Cast' || 'Spawn' => const Color(0xFF1D4ED8),
      'Widget' => const Color(0xFF9333EA),
      'Network' => const Color(0xFF0F766E),
      'Math' || 'Operator' => const Color(0xFF0D9488),
      'String' || 'Text' => const Color(0xFFBE185D),
      'Timeline' => const Color(0xFF7C3AED),
      'Comment' => const Color(0xFFFFC107),
      _ => const Color(0xFF2563EB),
    };
  }

  static Color functionHeaderColor({required bool pure}) {
    return pure ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
  }

  static Color pinColor(String dataType) {
    return switch (dataType.trim().toLowerCase()) {
      'exec' => Colors.white,
      'bool' || 'boolean' => const Color(0xFFDC2626),
      'byte' => const Color(0xFF0F766E),
      'int' ||
      'integer' ||
      'int32' ||
      'int64' ||
      'float' ||
      'real' ||
      'double' => const Color(0xFF22C55E),
      'string' || 'text' || 'name' => const Color(0xFFD946EF),
      'object' ||
      'actor' ||
      'component' ||
      'widget' ||
      'softobject' ||
      'soft object' => const Color(0xFF2563EB),
      'class' || 'softclass' || 'soft class' => const Color(0xFF7C3AED),
      'interface' => const Color(0xFF14B8A6),
      'struct' => const Color(0xFFF59E0B),
      'vector' || 'vector2d' || 'vector4' => const Color(0xFFEAB308),
      'rotator' => const Color(0xFFA855F7),
      'transform' => const Color(0xFFF97316),
      'linearcolor' || 'color' => const Color(0xFFEC4899),
      'enum' => const Color(0xFF06B6D4),
      'array' || 'set' || 'map' => const Color(0xFF06B6D4),
      'delegate' || 'event dispatcher' => const Color(0xFFF43F5E),
      'wildcard' => const Color(0xFF94A3B8),
      _ => const Color(0xFF2563EB),
    };
  }

  static Color variableColor(String dataType) {
    return pinColor(dataType);
  }

  static Color variableTint(String dataType, {double alpha = 0.10}) {
    return variableColor(dataType).withValues(alpha: alpha);
  }

  static IconData icon(String nodeType) {
    return switch (nodeType) {
      'CustomEvent' => Icons.flash_on,
      'EventCall' => Icons.flash_on_outlined,
      'Event' => Icons.bolt,
      'Function' || 'FunctionCall' => Icons.functions,
      'Branch' || 'FlowControl' => Icons.call_split,
      'Variable' || 'VariableGet' || 'VariableSet' => Icons.data_object,
      'Latent' => Icons.timer_outlined,
      'Container' => Icons.dataset_outlined,
      'Object' || 'Class' || 'Cast' || 'Spawn' => Icons.category_outlined,
      'Widget' => Icons.widgets_outlined,
      'Network' => Icons.sync_alt,
      'Math' || 'Operator' => Icons.calculate_outlined,
      'String' || 'Text' => Icons.text_fields,
      'Timeline' => Icons.timeline,
      'Comment' => Icons.sticky_note_2_outlined,
      _ => Icons.account_tree_outlined,
    };
  }
}
