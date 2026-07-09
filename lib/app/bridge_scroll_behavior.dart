import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const Duration kBridgeWheelScrollDuration = Duration(milliseconds: 110);
const Curve kBridgeWheelScrollCurve = Curves.easeOutCubic;

class BridgeScrollBehavior extends MaterialScrollBehavior {
  const BridgeScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final scrollable = SmoothWheelScrollWrapper(
      controller: details.controller,
      direction: details.direction,
      child: child,
    );

    return Scrollbar(
      controller: details.controller,
      thumbVisibility: false,
      interactive: true,
      radius: const Radius.circular(999),
      child: scrollable,
    );
  }
}

class SmoothWheelScrollWrapper extends StatefulWidget {
  const SmoothWheelScrollWrapper({
    required this.controller,
    required this.direction,
    required this.child,
    super.key,
  });

  final ScrollController? controller;
  final AxisDirection direction;
  final Widget child;

  @override
  State<SmoothWheelScrollWrapper> createState() =>
      _SmoothWheelScrollWrapperState();
}

class _SmoothWheelScrollWrapperState extends State<SmoothWheelScrollWrapper> {
  bool _pendingMouseWheel = false;
  bool _isRewindingPointerJump = false;
  double? _animatedTarget;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) {
      return widget.child;
    }

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        _smoothPointerScrollUpdate(controller, notification);
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (event) {
          if (event is PointerScrollEvent &&
              event.kind == PointerDeviceKind.mouse &&
              controller.hasClients &&
              _scrollDeltaForDirection(event.scrollDelta, widget.direction) !=
                  0) {
            _pendingMouseWheel = true;
          }
        },
        child: widget.child,
      ),
    );
  }

  void _smoothPointerScrollUpdate(
    ScrollController controller,
    ScrollUpdateNotification notification,
  ) {
    final delta = notification.scrollDelta;
    if (!_pendingMouseWheel ||
        _isRewindingPointerJump ||
        delta == null ||
        delta == 0 ||
        !controller.hasClients) {
      return;
    }

    _pendingMouseWheel = false;

    final position = controller.position;
    final jumpedTo = position.pixels;
    final jumpedFrom = (jumpedTo - delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final target = ((_animatedTarget ?? jumpedFrom) + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if (target == jumpedFrom) {
      return;
    }

    _animatedTarget = target;
    _isRewindingPointerJump = true;
    position.jumpTo(jumpedFrom);
    _isRewindingPointerJump = false;

    scheduleMicrotask(() {
      if (!mounted || !controller.hasClients || _animatedTarget != target) {
        return;
      }

      controller
          .animateTo(
            target,
            duration: kBridgeWheelScrollDuration,
            curve: kBridgeWheelScrollCurve,
          )
          .whenComplete(() {
            if (!mounted || _animatedTarget != target) {
              return;
            }
            _animatedTarget = null;
          });
    });
  }

  double _scrollDeltaForDirection(Offset scrollDelta, AxisDirection direction) {
    return switch (direction) {
      AxisDirection.down => scrollDelta.dy,
      AxisDirection.up => -scrollDelta.dy,
      AxisDirection.right => scrollDelta.dx,
      AxisDirection.left => -scrollDelta.dx,
    };
  }
}
