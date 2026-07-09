import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ImeControl {
  const ImeControl._();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'unreal_blueprint_bridge/ime',
  );

  static Future<void> setEnabled(bool enabled) async {
    try {
      await channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // Non-Windows test/runtime surfaces do not need native IME control.
    }
  }
}
