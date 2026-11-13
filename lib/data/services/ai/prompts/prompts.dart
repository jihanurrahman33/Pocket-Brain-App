import 'package:intl/intl.dart';

import '../../../../core/utils/text_utils.dart';
import '../../../../domain/entities/ask.dart';
import '../../../../domain/entities/conversation.dart';
import '../../../../domain/entities/memory.dart';
import '../../../datasources/ai/on_device_ai_runtime.dart';

/// Builds the prompt that asks Gemma to analyse a captured note.
abstract final class AnalysisPrompt {
  static const _maxNoteChars = 6000;

  static GenerationRequest build(String note, DateTime today) => GenerationRequest(
    systemInstruction: 'You organise notes for a personal memory app. Reply with JSON only.',
    maxOutputTokens: 400,
    temperature: 0.2,
    prompt:
        '''
Today is ${DateFormat('yyyy-MM-dd (EEEE)').format(today)}.
Analyse the note below and return a JSON object with these keys:
- "title": a short title, at most 8 words
- "summary": one or two sentences
- "category": one of ${MemoryCategories.defaults.map((c) => '"$c"').join(', ')}
- "tags": 2 to 5 short lowercase tags
- "people": names of people mentioned (may be empty)
- "tasks": actions the writer must do, each {"title": "...", "due": "YYYY-MM-DD" or null}. Empty if none.
Do not add facts that are not in the note.

NOTE:
"""
${TextUtils.truncate(note, _maxNoteChars)}
"""''',
  );
}

/// Builds a grounded, cited Ask Brain prompt.
abstract final class AnswerPromptBuilder {
  static const _maxSourceChars = 1200;
  static const _maxHistoryTurns = 4;
  static const _maxTurnChars = 400;

  static GenerationRequest build(AnswerPrompt input) {
    final prompt = StringBuffer()..writeln('SAVED MEMORIES:');
    for (final (i, m) in input.sources.indexed) {
      prompt
        ..writeln('[${i + 1}] ${m.title} (saved ${DateFormat.yMMMd().format(m.createdAt)})')
        ..writeln(TextUtils.truncate(m.content, _maxSourceChars))
        ..writeln();
    }
    final history = input.history.length > _maxHistoryTurns
        ? input.history.sublist(input.history.length - _maxHistoryTurns)
        : input.history;
    if (history.isNotEmpty) {
      prompt.writeln('EARLIER IN THIS CONVERSATION:');
      for (final turn in history) {
        final speaker = turn.role == ChatRole.user ? 'User' : 'Assistant';
        prompt.writeln('$speaker: ${TextUtils.truncate(turn.text, _maxTurnChars)}');
      }
      prompt.writeln();
    }
    prompt
      ..writeln('QUESTION: ${input.question}')
      ..writeln()
      ..writeln(
        'Answer using only the saved memories above. Cite them like [1] or [2]. '
        'If they do not contain the answer, reply exactly: "${AskReplies.notFound}"',
      );
    return GenerationRequest(
      systemInstruction:
          'You are Pocket Brain, a personal memory assistant. You only know what '
          'the user saved. Never use outside knowledge or invent details. Be concise.',
      prompt: prompt.toString(),
      maxOutputTokens: 600,
    );
  }
}

/// Builds the weekly recap prompt.
abstract final class RecapPrompt {
  static const _maxItems = 12;
  static const _maxItemChars = 200;

  static GenerationRequest build(List<Memory> memories) {
    final notes = memories
        .take(_maxItems)
        .map((m) => '- ${m.title}: ${TextUtils.truncate(m.preview, _maxItemChars)}')
        .join('\n');
    return GenerationRequest(
      systemInstruction: 'You write warm, brief recaps of what someone saved.',
      maxOutputTokens: 200,
      prompt:
          'Here is what I saved this week:\n$notes\n\n'
          'In 2-3 sentences, tell me the main themes and how they connect. '
          'Only mention things in the list.',
    );
  }
}
