import '../../core/utils/text_utils.dart';

/// Safety and quality rules applied around every Ask Brain answer. Pure and
/// deterministic, so they hold no matter what the model does.
///
/// Order: [prepareQuestion] → [safetyReply] → [conversationalReply] →
/// (retrieval + model) → [cleanAnswer] → grounding check in `AskBrain`.
abstract final class AssistantGuardrails {
  /// Longer questions are cut; they would crowd the memories out of context.
  static const maxQuestionChars = 1000;

  /// Answers are capped so a runaway generation cannot flood the chat.
  static const maxAnswerChars = 2500;

  static final _whitespace = RegExp(r'\s+');

  /// Trims, collapses whitespace and bounds the length.
  static String prepareQuestion(String question) {
    final clean = question.replaceAll(_whitespace, ' ').trim();
    return clean.length <= maxQuestionChars ? clean : clean.substring(0, maxQuestionChars);
  }

  // ------------------------------------------------------------- safety

  static final _crisis = RegExp(
    r'\b(kill myself|end my life|suicid\w*|self[- ]?harm|want to die|hurt myself|'
    r'atmohott?a|attohotta|morte chai|mor[e]? jete chai)\b',
    caseSensitive: false,
  );

  /// A caring, fixed reply for messages about self-harm. The model is not
  /// asked: this must never depend on what a small model happens to write.
  static String? safetyReply(String question) => _crisis.hasMatch(question)
      ? "I'm really sorry you're feeling this way. You don't have to go through it alone. "
            'Please reach out to someone you trust, or contact your local emergency number '
            'or a crisis helpline right now. If you are in immediate danger, call emergency '
            'services.'
      : null;

  // ------------------------------------------------- conversational intents

  static final _help = RegExp(
    r'^(what (can|do) you do|what are you|who are you|how (do|can) (i|you) use|help|'
    r'how does this (app )?work|what can i ask|tumi ki korte paro|ki ki korte paro|'
    r'tumi ke|apni ki korte paren|ki korte paro)\b',
    caseSensitive: false,
  );
  static final _greeting = RegExp(
    r'^(hi|hello|hey|good (morning|afternoon|evening)|assalamu ?alaikum|salam|'
    r'kemon acho|kemon achen|hola)\b[\s!.?]*$',
    caseSensitive: false,
  );
  static final _thanks = RegExp(
    r'^(thanks|thank you|thx|dhonnobad|dhanyabad|shukriya)\b',
    caseSensitive: false,
  );

  static const helpReply =
      'I am Pocket Brain, your private memory assistant. Everything runs on this device.\n\n'
      '• Ask about anything you saved: "What was that book I was reading?"\n'
      '• Summarise a topic: "Summarise everything I saved about RAG."\n'
      '• Check your tasks: "What is overdue?"\n'
      '• Create a task or reminder: "Remind me to call the dentist on Friday."\n'
      '• Save a note: "Remember that my locker code is 4312."\n\n'
      'I only answer from your memories. Tasks and notes I suggest are saved only after '
      'you tap Confirm. You can ask in English or Bangla.';

  /// Fixed replies for questions about the assistant itself, greetings and
  /// thanks — these are not questions about the user's memories.
  static String? conversationalReply(String question) {
    final q = question.trim().toLowerCase();
    if (_help.hasMatch(q)) return helpReply;
    if (_greeting.hasMatch(q)) {
      return 'Hi! Ask me about anything you saved, or tell me what to remember.';
    }
    if (_thanks.hasMatch(q)) return "You're welcome!";
    return null;
  }

  // --------------------------------------------------------------- output

  static final _citation = RegExp(r'\[(\d+)\]');
  static final _emphasis = RegExp(r'\*\*|__|(?<=\s|^)\*(?=\S)|(?<=\S)\*(?=\s|$)');
  static final _toolMarkup = RegExp(
    r'<\/?(start_function_call|end_function_call|tool_call|function_call)[^>]*>|'
    r'```(?:json)?\s*\{[^`]*"(tool_calls|name)"[^`]*\}\s*```',
    caseSensitive: false,
  );

  /// Removes leaked tool-call markup and citations that point at no source,
  /// and bounds the length.
  static String cleanAnswer(String text, {required int sourceCount}) {
    final withoutMarkup = text
        .replaceAll(_toolMarkup, '')
        // Answers render as plain text: drop markdown emphasis markers.
        .replaceAll(_emphasis, '');
    final validCitations = withoutMarkup.replaceAllMapped(_citation, (m) {
      final n = int.parse(m[1]!);
      return n >= 1 && n <= sourceCount ? m[0]! : '';
    });
    final tidy = validCitations
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(' {2,}'), ' ')
        .trim();
    return tidy.length <= maxAnswerChars ? tidy : TextUtils.truncate(tidy, maxAnswerChars);
  }
}
