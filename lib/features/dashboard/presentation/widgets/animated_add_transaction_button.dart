import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class AnimatedAddTransactionButton extends StatefulWidget {
  const AnimatedAddTransactionButton({super.key, required this.onPressed});
  final Future<void> Function() onPressed;

  @override
  State<AnimatedAddTransactionButton> createState() =>
      _AnimatedAddTransactionButtonState();
}

class _AnimatedAddTransactionButtonState
    extends State<AnimatedAddTransactionButton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.06), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 25),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  late final _turns = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.125), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 0.125, end: 0.0), weight: 50),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  bool _opening = false;

  Future<void> _activate() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _controller.forward(from: 0).orCancel;
      }
      if (!mounted) return;
      _controller.reset();
      await widget.onPressed();
    } on TickerCanceled {
      // The screen was closed before the animation finished.
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: Semantics(
          label: 'Nova movimentação',
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: _opening ? null : _activate,
            child:
                RotationTransition(turns: _turns, child: const Icon(Icons.add)),
          ),
        ),
      );
}
