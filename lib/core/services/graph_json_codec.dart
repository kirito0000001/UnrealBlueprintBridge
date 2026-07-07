import 'dart:convert';

import '../models/graph_document.dart';

class GraphJsonCodec {
  const GraphJsonCodec();

  String encode(GraphDocument document) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(document.toJson());
  }

  GraphDocument decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Graph JSON root must be an object.');
    }

    return GraphDocument.fromJson(decoded);
  }
}
