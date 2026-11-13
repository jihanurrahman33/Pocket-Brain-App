import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/usecases/memories/memory_usecases.dart';

/// Opens the edit form — full screen on phones, a dialog on larger
/// windows — and returns the edit, or null if cancelled.
Future<MemoryEdit?> showEditMemoryDialog(BuildContext context, Memory memory) async {
  final form = _EditMemoryFormController(memory);
  try {
    return await showAdaptiveFormDialog<MemoryEdit>(
      context: context,
      title: 'Edit memory',
      confirmLabel: 'Save',
      builder: (_) => _EditMemoryFields(form: form),
      onConfirm: form.toEdit,
    );
  } finally {
    form.dispose();
  }
}

/// Holds the form's text controllers (separate from the widgets that show
/// them, so the dialog route can be rebuilt freely).
class _EditMemoryFormController {
  _EditMemoryFormController(this.memory)
    : title = TextEditingController(text: memory.title),
      content = TextEditingController(text: memory.content),
      summary = TextEditingController(text: memory.summary),
      tags = TextEditingController(text: memory.tags.join(', ')),
      category = ValueNotifier(memory.category);

  final Memory memory;
  final TextEditingController title;
  final TextEditingController content;
  final TextEditingController summary;
  final TextEditingController tags;
  final ValueNotifier<String> category;

  MemoryEdit toEdit() => MemoryEdit(
    id: memory.id,
    title: title.text,
    content: content.text,
    summary: summary.text,
    category: category.value,
    tags: [
      for (final tag in tags.text.split(','))
        if (tag.trim().isNotEmpty) tag.trim().toLowerCase(),
    ],
  );

  void dispose() {
    title.dispose();
    content.dispose();
    summary.dispose();
    tags.dispose();
    category.dispose();
  }
}

class _EditMemoryFields extends StatelessWidget {
  const _EditMemoryFields({required this.form});

  final _EditMemoryFormController form;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        controller: form.title,
        decoration: const InputDecoration(labelText: 'Title'),
      ),
      const Gap.md(),
      TextField(
        controller: form.content,
        minLines: 4,
        maxLines: 12,
        decoration: const InputDecoration(labelText: 'Your text'),
      ),
      const Gap.md(),
      TextField(
        controller: form.summary,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Summary'),
      ),
      const Gap.md(),
      ValueListenableBuilder(
        valueListenable: form.category,
        builder: (context, category, _) => DropdownButtonFormField<String>(
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in {...MemoryCategories.defaults, category})
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => form.category.value = v ?? category,
        ),
      ),
      const Gap.md(),
      TextField(
        controller: form.tags,
        decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
      ),
    ],
  );
}
