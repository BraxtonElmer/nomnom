import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../ui/format.dart';
import '../../ui/pressable.dart';

/// "What did you eat?" bar. While focused, favourites and recent plates
/// float above it for one-tap logging.
class Composer extends StatefulWidget {
  const Composer({super.key, required this.onSubmit, required this.onQuick});

  final ValueChanged<String> onSubmit;

  /// Re-log a saved plate without asking the AI.
  final void Function(String title, List<FoodItem> items) onQuick;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _focus.unfocus();
    _text.clear();
    widget.onSubmit(t);
  }

  List<(String, List<FoodItem>, double, bool)> get _quick {
    final out = <(String, List<FoodItem>, double, bool)>[];
    final seen = <String>{};
    for (final f in Store.i.favourites) {
      if (seen.add(f.title.toLowerCase())) out.add((f.title, f.items, f.total.kcal, true));
    }
    for (final e in Store.i.recents()) {
      if (seen.add(e.title.toLowerCase())) out.add((e.title, e.items, e.total.kcal, false));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final quick = _quick;
    final open = _focus.hasFocus && _text.text.isEmpty && quick.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.curve,
          alignment: Alignment.bottomCenter,
          child: open
              ? SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: quick.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final (title, items, k, fav) = quick[i];
                      return Pressable(
                        onTap: () {
                          _focus.unfocus();
                          widget.onQuick(title, items);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: C.card,
                            border: Border.all(color: C.lineStrong),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (fav) ...[
                                Icon(Icons.star_rounded, size: 15, color: C.tomato),
                                const SizedBox(width: 4),
                              ],
                              Text(title, style: T.small.copyWith(color: C.ink)),
                              const SizedBox(width: 6),
                              Text(kcal(k), style: T.small),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: C.ink),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _submit(),
                      style: T.body.copyWith(fontSize: 16),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        hintText: 'What did you eat?',
                        hintStyle: T.body.copyWith(fontSize: 16, color: C.ink3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: _text.text.trim().isEmpty ? null : _submit,
                  scale: 0.88,
                  semanticLabel: 'Log it',
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _text.text.trim().isEmpty ? C.ink3 : C.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_upward_rounded, color: C.paper, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
