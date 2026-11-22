/// The language to answer in, detected without a model.
enum ReplyLanguage {
  english('English'),
  bangla('Bangla (in Bengali script)'),

  /// Answered in Bengali script: small models write romanised Bangla poorly
  /// (it has no standard spelling), but Bengali script well.
  banglish('Bangla, using Bengali script (the user typed Bangla in English letters)');

  const ReplyLanguage(this.instruction);

  /// How the prompt names the language for the model.
  final String instruction;
}

/// Cheap, deterministic language detection for English, Bangla and Bangla
/// written in English letters. Small models follow an explicit "reply in X"
/// far better than "reply in the user's language".
abstract final class LanguageDetector {
  static final _bengaliScript = RegExp(r'[ঀ-৿]');

  /// Common Bangla words as typed in English letters.
  static const _banglishWords = {
    'ami',
    'amar',
    'amake',
    'tumi',
    'tomar',
    'apni',
    'apnar',
    'ki',
    'kobe',
    'keno',
    'kothay',
    'kivabe',
    'kemon',
    'eta',
    'ota',
    'ei',
    'oi',
    'ache',
    'achhe',
    'nai',
    'na',
    'hobe',
    'hoy',
    'hoise',
    'hoyeche',
    'korbo',
    'korte',
    'korsi',
    'korechi',
    'portesilam',
    'portesi',
    'porchi',
    'boi',
    'sesh',
    'kaj',
    'kal',
    'aj',
    'ajke',
    'gulo',
    'shob',
    'sob',
    'jonno',
    'theke',
    'diye',
    'bolo',
    'dao',
    'mone',
    'koro',
  };
  static const _minBanglishWords = 2;
  static final _word = RegExp(r'[a-z]+');

  static ReplyLanguage detect(String text) {
    if (_bengaliScript.hasMatch(text)) return ReplyLanguage.bangla;
    final words = _word.allMatches(text.toLowerCase()).map((m) => m[0]!);
    final hits = words.where(_banglishWords.contains).length;
    return hits >= _minBanglishWords ? ReplyLanguage.banglish : ReplyLanguage.english;
  }
}
