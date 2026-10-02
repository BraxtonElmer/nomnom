import 'package:flutter/material.dart';

import '../data/updater.dart';
import '../theme/tokens.dart';
import '../ui/buttons.dart';
import '../ui/controls.dart';

/// On Today when a newer release is out: one line, tap for the details.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Updater.i,
      builder: (context, _) {
        final r = Updater.i.available;
        if (r == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(S.radius),
              border: Border.all(color: C.lineStrong),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Update found · ${r.version}', style: T.bodyStrong),
                      Text('See what’s new and install it', style: T.small),
                    ],
                  ),
                ),
                TextLink(label: 'Update', onTap: () => showUpdateSheet(context, r)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Check for updates" from You: the sheet if there's one, else a toast.
Future<void> checkForUpdates(BuildContext context) async {
  showToast(context, 'Checking for updates…');
  final r = await Updater.i.check();
  if (!context.mounted) return;
  if (r == null) {
    showToast(context, 'You have the latest version (${Updater.i.current}).');
  } else {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await showUpdateSheet(context, r);
  }
}

Future<void> showUpdateSheet(BuildContext context, Release r) =>
    showPaperSheet<void>(context, (_) => _UpdateSheet(release: r));

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({required this.release});

  final Release release;

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> with WidgetsBindingObserver {
  /// Waiting for the user to allow installs in Android's settings.
  bool _askedToAllow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Android's "allow installs" screen: carry on if it was allowed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _askedToAllow) {
      _askedToAllow = false;
      _update();
    }
  }

  Future<void> _update() async {
    final u = Updater.i;
    if (!await u.canInstall()) {
      setState(() => _askedToAllow = true);
      await u.allowInstalls();
      return;
    }
    await u.install(widget.release);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    return ListenableBuilder(
      listenable: Updater.i,
      builder: (context, _) {
        final u = Updater.i;
        final busy = u.progress != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('nomnom ${r.version}', style: T.heading),
              Text(u.current.isEmpty ? 'A new version' : 'You have ${u.current}', style: T.small),
              const SizedBox(height: 16),
              if (r.notes.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                  child: SingleChildScrollView(child: Text(r.notes, style: T.body)),
                ),
              const SizedBox(height: 18),
              if (busy) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: u.progress,
                    minHeight: 4,
                    color: C.ink,
                    backgroundColor: C.line,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Downloading… ${((u.progress ?? 0) * 100).round()}%', style: T.small),
                const SizedBox(height: 12),
              ],
              if (u.error != null) ...[
                Text(u.error!, style: T.small.copyWith(color: C.tomato)),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: u.error != null ? 'Try again' : 'Update',
                busy: busy,
                onTap: busy ? null : _update,
              ),
              const SizedBox(height: 8),
              Text(
                'Android asks you to confirm the install. Your log and settings stay as they are.',
                style: T.small,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextLink(label: 'Later', color: C.ink2, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 24),
                  TextLink(
                    label: 'Skip this version',
                    color: C.ink2,
                    onTap: () async {
                      await u.skip(r);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
