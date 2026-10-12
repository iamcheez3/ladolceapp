import 'package:flutter/widgets.dart';

/// Runs [onDispose] when this subtree leaves the tree.
///
/// A dialog or sheet built inline cannot dispose its controllers right after
/// `await showDialog(...)`: the route is still animating out and its fields
/// still use them, which fails `_dependents.isEmpty` (red screen on Cancel).
/// Wrap the route's content in this widget and dispose them here instead,
/// once the route and its fields are gone.
class DisposeWith extends StatefulWidget {
  final VoidCallback onDispose;
  final Widget child;

  const DisposeWith({super.key, required this.onDispose, required this.child});

  @override
  State<DisposeWith> createState() => _DisposeWithState();
}

class _DisposeWithState extends State<DisposeWith> {
  @override
  void dispose() {
    // Children are unmounted first, so nothing listens any more.
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
