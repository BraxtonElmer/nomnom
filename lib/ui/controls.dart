import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

class Hairline extends StatelessWidget {
  const Hairline({super.key, this.strong = false, this.indent = 0});

  final bool strong;
  final double indent;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsets.symmetric(horizontal: indent),
    color: strong ? C.ink : C.line,
  );
}

/// Underlined text segments, the Paper way of showing a choice.
class TextTabs<V> extends StatelessWidget {
  const TextTabs({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final List<V> values;
  final List<String> labels;
  final V value;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      children: [
        for (var i = 0; i < values.length; i++)
          Pressable(
            onTap: () => onChanged(values[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: AnimatedDefaultTextStyle(
                duration: Motion.fast,
                style: T.body.copyWith(
                  color: values[i] == value ? C.ink : C.ink2,
                  fontWeight: values[i] == value ? FontWeight.w600 : FontWeight.w400,
                  decoration: values[i] == value ? TextDecoration.underline : TextDecoration.none,
                  decorationThickness: 1.5,
                ),
                child: Text(labels[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Capsule segmented control with a sliding card under the selection.
class Segmented<V> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final List<V> values;
  final List<String> labels;
  final V value;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(value);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: C.paperDeep, borderRadius: BorderRadius.circular(999)),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.base,
                curve: Motion.curve,
                left: w * (index < 0 ? 0 : index),
                top: 0,
                bottom: 0,
                width: w,
                child: AnimatedOpacity(
                  opacity: index < 0 ? 0 : 1,
                  duration: Motion.fast,
                  child: Container(
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F1A1916), blurRadius: 2, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Pressable(
                        scale: 0.94,
                        onTap: () => onChanged(values[i]),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: T.small.copyWith(
                              color: i == index ? C.ink : C.ink2,
                              fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Outlined − value + stepper.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.label, required this.onMinus, required this.onPlus});

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    Widget btn(String s, String semantic, VoidCallback? f) => Pressable(
      onTap: f,
      scale: 0.85,
      semanticLabel: semantic,
      child: SizedBox(
        width: 40,
        height: 36,
        child: Center(child: Text(s, style: T.body.copyWith(fontSize: 18))),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: C.ink),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn('−', 'Less', onMinus),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 58),
            child: AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: Text(label, key: ValueKey(label), textAlign: TextAlign.center, style: T.body),
            ),
          ),
          btn('+', 'More', onPlus),
        ],
      ),
    );
  }
}

/// Underlined field with a small caps label.
class PaperField extends StatelessWidget {
  const PaperField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.keyboard,
    this.obscure = false,
    this.onChanged,
    this.formatters,
    this.autofocus = false,
    this.mono = false,
    this.trailingGap = 0,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? suffix;
  final TextInputType? keyboard;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? formatters;
  final bool autofocus;
  final bool mono;
  final double trailingGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: T.caps),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          obscureText: obscure,
          autofocus: autofocus,
          onChanged: onChanged,
          inputFormatters: formatters,
          autocorrect: false,
          enableSuggestions: !obscure,
          style: T.body.copyWith(fontSize: 18, letterSpacing: obscure ? 1.5 : 0),
          cursorColor: C.tomato,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            // Leave room for a trailing icon laid over the field (show key).
            contentPadding: EdgeInsets.fromLTRB(0, 12, trailingGap, 12),
            hintStyle: T.body.copyWith(fontSize: 18, color: C.ink3),
            suffixText: suffix,
            suffixStyle: T.small,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: C.ink, width: 1.2),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: C.tomato, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// A row in a ruled list: label left, value right, optional chevron.
class RuledRow extends StatelessWidget {
  const RuledRow({
    super.key,
    required this.label,
    this.value,
    this.onTap,
    this.last = false,
    this.leading,
    this.danger = false,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool last;
  final Widget? leading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Text(label, style: T.body.copyWith(color: danger ? C.tomato : C.ink)),
          ),
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                value!,
                style: T.small,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 20, color: C.ink3),
          ],
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, scale: 0.99, child: row);
  }
}

/// Bottom sheet on card paper with a grabber.
Future<R?> showPaperSheet<R>(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: C.card,
    barrierColor: const Color(0x661A1916),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: C.lineStrong, borderRadius: BorderRadius.circular(4)),
          ),
          Flexible(child: builder(context)),
        ],
      ),
    ),
  );
}

void showToast(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.ink,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 3),
      content: Text(message, style: T.body.copyWith(color: C.paper)),
      action: action == null
          ? null
          : SnackBarAction(label: action, textColor: C.tomatoSoft, onPressed: onAction ?? () {}),
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showPaperSheet<bool>(
    context,
    (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: T.heading),
          const SizedBox(height: 8),
          Text(body, style: T.body.copyWith(color: C.ink2)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: C.ink),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Cancel', style: T.bodyStrong),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.tomato,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(action, style: T.button.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// Ink pill switch.
class PaperSwitch extends StatelessWidget {
  const PaperSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: label,
    child: Pressable(
      onTap: () => onChanged(!value),
      scale: 0.92,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? C.ink : C.paperDeep,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: value ? C.ink : C.lineStrong),
        ),
        child: AnimatedAlign(
          duration: Motion.base,
          curve: Motion.curve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: value ? C.paper : C.card, shape: BoxShape.circle),
          ),
        ),
      ),
    ),
  );
}
