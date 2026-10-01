import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.trailing,
    this.busy = false,
    this.color,
  });

  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(color: color ?? C.ink, borderRadius: BorderRadius.circular(999)),
        child: AnimatedSwitcher(
          duration: Motion.fast,
          child: busy
              ? Center(
                  key: ValueKey('busy'),
                  child: Dots(color: C.paper),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: trailing == null
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: T.button),
                    if (trailing != null)
                      Text(
                        trailing!,
                        style: T.button.copyWith(
                          fontFamily: F.serif,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({super.key, required this.label, this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: C.ink),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: C.ink), const SizedBox(width: 8)],
            Text(label, style: T.bodyStrong),
          ],
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.filled = false,
    this.size = 44,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? C.ink : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: filled ? C.paper : C.ink),
      ),
    );
  }
}

class TextLink extends StatelessWidget {
  const TextLink({super.key, required this.label, this.onTap, this.color});

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          style: T.small.copyWith(color: color ?? C.tomato, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Three breathing dots, used anywhere we wait on the AI.
class Dots extends StatefulWidget {
  const Dots({super.key, this.color, this.size = 6});

  final Color? color;
  final double size;

  @override
  State<Dots> createState() => _DotsState();
}

class _DotsState extends State<Dots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value - i * 0.18) % 1.0);
          final o = 0.25 + 0.75 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size / 3),
            child: Opacity(
              opacity: o.clamp(0.25, 1.0),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(color: widget.color ?? C.ink, shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}
