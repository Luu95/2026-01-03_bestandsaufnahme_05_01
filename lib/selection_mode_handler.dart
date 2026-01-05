import 'package:flutter/material.dart';

class SelectionModeHandler extends StatefulWidget {
  final bool isSelectionMode;
  final void Function(bool) onSelectionChanged;
  final String label;

  const SelectionModeHandler({
    Key? key,
    required this.isSelectionMode,
    required this.onSelectionChanged,
    required this.label,
  }) : super(key: key);

  @override
  _SelectionModeHandlerState createState() => _SelectionModeHandlerState();
}

class _SelectionModeHandlerState extends State<SelectionModeHandler>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    );

    if (widget.isSelectionMode) {
      _rotationController.forward();
    } else {
      _rotationController.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant SelectionModeHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelectionMode != oldWidget.isSelectionMode) {
      if (widget.isSelectionMode) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
      widget.onSelectionChanged(widget.isSelectionMode);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            widget.onSelectionChanged(false); // Zurücksetzen
          },
          child: RotationTransition(
            turns: _rotationAnimation,
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          widget.isSelectionMode ? '${widget.label} aktiviert' : 'Normalmodus',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
// TODO Implement this library.