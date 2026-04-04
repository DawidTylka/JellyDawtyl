import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class DesktopHorizontalListView extends StatefulWidget {
  final double height;
  final EdgeInsetsGeometry? padding;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool thumbVisibility;

  const DesktopHorizontalListView({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.thumbVisibility = false,
  });

  @override
  State<DesktopHorizontalListView> createState() =>
      _DesktopHorizontalListViewState();
}

class _DesktopHorizontalListViewState extends State<DesktopHorizontalListView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) {
      return;
    }

    final delta = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;

    if (delta == 0) {
      return;
    }

    final position = _controller.position;
    final target = math.min(
      math.max(position.pixels + delta, position.minScrollExtent),
      position.maxScrollExtent,
    );

    if (target != position.pixels) {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
              PointerDeviceKind.unknown,
            },
          ),
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: widget.thumbVisibility,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: ListView.builder(
              controller: _controller,
              primary: false,
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              itemCount: widget.itemCount,
              itemBuilder: widget.itemBuilder,
            ),
          ),
        ),
      ),
    );
  }
}
