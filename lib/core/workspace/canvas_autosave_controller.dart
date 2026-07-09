import 'dart:async';

typedef AutosaveAction<T> = Future<void> Function(T value);

class AutosaveController<T> {
  AutosaveController({required this.save, required this.delay});

  final AutosaveAction<T> save;
  final Duration delay;

  Timer? _timer;
  T? _pendingValue;

  void schedule(T value) {
    _pendingValue = value;
    _timer?.cancel();
    _timer = Timer(delay, () {
      final value = _pendingValue;
      _pendingValue = null;
      if (value == null) {
        return;
      }

      unawaited(save(value));
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;

    final value = _pendingValue;
    _pendingValue = null;
    if (value == null) {
      return;
    }

    await save(value);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pendingValue = null;
  }
}

typedef CanvasAutosaveController<T> = AutosaveController<T>;
