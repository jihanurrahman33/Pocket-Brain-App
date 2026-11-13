import 'package:flutter/material.dart';

import '../responsive/window_size.dart';
import '../theme/app_spacing.dart';

/// Shows [builder]'s content as a full-screen page on compact windows and
/// as a centred dialog elsewhere. [builder] returns the form body; the
/// caller provides the title and primary action.
Future<T?> showAdaptiveFormDialog<T>({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  required Widget Function(BuildContext context) builder,
  required T? Function() onConfirm,
  double dialogWidth = 560,
}) {
  if (context.windowSize.isCompact) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, onConfirm()),
                child: Text(confirmLabel),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: builder(context),
            ),
          ),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(child: builder(context)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, onConfirm()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Asks for one line of text.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String hint = '',
  String confirmLabel = 'Save',
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// Asks the user to confirm a destructive action.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

/// Picks an optional date (and time when [withTime]).
Future<DateTime?> pickDate(
  BuildContext context, {
  required String helpText,
  DateTime? initial,
  bool withTime = false,
}) async {
  const maxYearsAhead = 10;
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: now.subtract(const Duration(days: 1)),
    lastDate: DateTime(now.year + maxYearsAhead),
    helpText: helpText,
  );
  if (date == null || !withTime || !context.mounted) return date;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
