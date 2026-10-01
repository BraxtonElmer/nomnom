import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme/tokens.dart';
import '../ui/pressable.dart';
import 'history/history_screen.dart';
import 'pantry/pantry_screen.dart';
import 'progress/progress_screen.dart';
import 'today/today_screen.dart';
import 'you/you_screen.dart';

/// Five tabs kept alive in an IndexedStack, so switching never rebuilds or
/// refetches anything.
class Shell extends StatefulWidget {
  const Shell({super.key});

  static final tab = ValueNotifier(0);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const _labels = ['Today', 'History', 'Progress', 'Pantry', 'You'];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Shell.tab,
      builder: (context, tab, _) => PopScope(
        canPop: tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Shell.tab.value = 0;
        },
        child: Scaffold(
          body: IndexedStack(
            index: tab,
            children: const [
              TodayScreen(),
              HistoryScreen(),
              ProgressScreen(),
              PantryScreen(),
              YouScreen(),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: C.line)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++)
                    Expanded(
                      child: Pressable(
                        onTap: () => Shell.tab.value = i,
                        scale: 0.92,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Motion.fast,
                            style: T.small.copyWith(
                              color: i == tab ? C.ink : C.ink2,
                              fontWeight: i == tab ? FontWeight.w600 : FontWeight.w400,
                              decoration: i == tab ? TextDecoration.underline : null,
                              decorationThickness: 1.6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_labels[i]),
                                // Pantry: a meal is waiting on a stock question.
                                if (i == 3)
                                  ListenableBuilder(
                                    listenable: Store.i,
                                    builder: (_, _) => Store.i.stockChecks.isEmpty
                                        ? const SizedBox.shrink()
                                        : Padding(
                                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                                            child: Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: C.tomato,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
