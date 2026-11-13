import 'dart:convert';
import 'dart:io';

import '../../../core/utils/text_utils.dart';
import '../../../domain/entities/capture.dart';
import '../../../domain/services/ai_services.dart';
import '../../datasources/ai/on_device_ai_runtime.dart';
import 'prompts/prompts.dart';

/// Reads images (OCR + description) and transcribes recordings with the
/// on-device language model. The runtime loads the vision or audio encoder
/// only for these requests and frees it afterwards.
final class GemmaMediaReader implements MediaReader {
  const GemmaMediaReader(this._runtime);

  final OnDeviceAiRuntime _runtime;

  @override
  bool get isAvailable => _runtime.isInstalled(AiModelKind.languageModel);

  @override
  Future<MediaReading> readImage(String path) async {
    final raw = await _runtime
        .generate(ImageReadingPrompt.build(await File(path).readAsBytes()))
        .join();
    return parseImageReading(raw);
  }

  @override
  Future<MediaReading> transcribe(String path) async {
    final raw = await _runtime
        .generate(TranscriptionPrompt.build(await File(path).readAsBytes()))
        .join();
    return MediaReading(extractedText: raw.trim());
  }

  /// Parses `{"text": ..., "description": ...}`, tolerating prose around it.
  /// Without valid JSON the whole reply is kept as the description.
  static MediaReading parseImageReading(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        if (jsonDecode(raw.substring(start, end + 1)) case final Map<String, Object?> json) {
          return MediaReading(
            extractedText: (json['text'] as String? ?? '').trim(),
            description: (json['description'] as String? ?? '').trim(),
          );
        }
      } on FormatException {
        // Fall through to the plain-text reading.
      }
    }
    return MediaReading(description: TextUtils.truncate(raw, 500));
  }
}
