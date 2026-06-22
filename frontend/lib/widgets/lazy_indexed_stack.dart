import 'package:flutter/material.dart';

/// Like [IndexedStack], but only builds (and inits) each child the first
/// time its tab becomes active, instead of all at once. Avoids firing every
/// tab's data-loading queries simultaneously on shell mount.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const LazyIndexedStack(
      {super.key, required this.index, required this.children});

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<bool> _built =
      List.generate(widget.children.length, (i) => i == widget.index);

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built[widget.index] = true;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _built[i] ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}
