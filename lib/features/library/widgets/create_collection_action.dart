import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../bloc/library_cubit.dart';

/// Asks for a name and creates a collection, reporting validation errors.
Future<void> showCreateCollectionDialog(BuildContext context) async {
  final cubit = context.read<LibraryCubit>();
  final name = await promptText(
    context,
    title: 'New collection',
    hint: 'e.g. Books to Read',
    confirmLabel: 'Create',
  );
  if (name == null || !context.mounted) return;
  final failure = await cubit.createCollection(name);
  if (failure != null && context.mounted) context.showFailure(failure);
}
