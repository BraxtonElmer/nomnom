import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/store.dart';
import '../../ui/controls.dart';

/// Everything lives on the phone, so a file you can keep elsewhere is the
/// only safety net. API keys are never included.
Future<void> exportBackup(BuildContext context) async {
  final name = 'nomnom-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
  final bytes = utf8.encode(Store.i.exportJson());
  try {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
      fileNameOverrides: [name],
      subject: 'nomnom backup',
    ));
  } catch (_) {
    if (context.mounted) showToast(context, "Couldn't open the share sheet.");
  }
}

Future<void> restoreBackup(BuildContext context) async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
  } catch (_) {
    if (context.mounted) showToast(context, "Couldn't open files.");
    return;
  }
  if (file == null || !context.mounted) return;

  if (Store.i.onboarded) {
    final ok = await confirm(context,
        title: 'Replace everything?',
        body: 'Your current log, weights and favourites will be replaced by the backup.',
        action: 'Restore');
    if (!ok) return;
  }
  try {
    final count = await Store.i.importJson(await file.xFile.readAsString());
    if (context.mounted) showToast(context, 'Restored $count entries.');
  } on FormatException {
    if (context.mounted) showToast(context, "That file isn't a nomnom backup.");
  } catch (_) {
    if (context.mounted) showToast(context, "Couldn't read that backup.");
  }
}
