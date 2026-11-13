import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../../core/utils/text_utils.dart';
import '../../../../domain/entities/ask.dart';
import '../../../../domain/entities/conversation.dart';
import '../../../../domain/entities/memory.dart';
import '../../../datasources/ai/on_device_ai_runtime.dart';

/// Builds the prompt that asks Gemma to analyse a captured note.
abstract final class AnalysisPrompt {
  static const _maxNoteChars = 6000;

  /// Enforced by the engine where supported, so the reply is valid JSON.
  static final schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'maxLength': 80},
      'summary': {'type': 'string'},
      'category': {'type': 'string', 'enum': MemoryCategories.defaults},
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'maxItems': 5,
      },
      'people': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'tasks': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'due': {'type': 'string', 'description': 'YYYY-MM-DD, or empty when none'},
          },
          'required': ['title', 'due'],
        },
      },
    },
    'required': ['title', 'summary', 'category', 'tags', 'people', 'tasks'],
  };

  static GenerationRequest build(String note, DateTime today) => GenerationRequest(
    jsonSchema: schema,
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
- "tasks": actions the writer must do, each {"title": "...", "due": "YYYY-MM-DD" or ""}. Empty if none.
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

  static GenerationRequest build(AnswerPrompt input, {bool withTools = false}) {
    final prompt = StringBuffer()..writeln('SAVED MEMORIES:');
    if (input.sources.isEmpty) prompt.writeln('(none matched this question)');
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
    if (withTools) {
      prompt.writeln(
        'If the user asks you to create a task or reminder, call create_task. If they '
        'ask you to remember or note something, call save_memory. For questions about '
        'their tasks or deadlines, call list_tasks. Never claim an action is done: '
        'the user confirms it.',
      );
    }
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

/// Reads text in an image and describes it (OCR + understanding).
abstract final class ImageReadingPrompt {
  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'text': {
        'type': 'string',
        'description': 'All readable text in the image, line by line. Empty if none.',
      },
      'description': {
        'type': 'string',
        'description': 'One or two sentences describing what the image shows.',
      },
    },
    'required': ['text', 'description'],
  };

  static GenerationRequest build(Uint8List image) => GenerationRequest(
    systemInstruction: 'You read images for a personal memory app. Reply with JSON only.',
    prompt:
        'Transcribe all readable text in this image exactly as written, keeping '
        'line breaks, then describe what the image shows in one or two sentences. '
        'Return {"text": "...", "description": "..."}. Do not guess unreadable text.',
    image: image,
    jsonSchema: schema,
    maxOutputTokens: 1024,
    temperature: 0.1,
  );
}

/// Transcribes speech in a recording.
abstract final class TranscriptionPrompt {
  static GenerationRequest build(Uint8List audio) => GenerationRequest(
    systemInstruction: 'You transcribe voice notes accurately.',
    prompt:
        'Transcribe this recording word for word. Reply with only the transcript, '
        'no commentary. If there is no speech, reply with nothing.',
    audio: audio,
    maxOutputTokens: 1024,
    temperature: 0.1,
  );
}
