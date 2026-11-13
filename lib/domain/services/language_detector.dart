/// The language to answer in, detected without a model.
enum ReplyLanguage {
  english('English'),
  bangla('Bangla (in Bengali script)'),
  banglish('Bangla written in English letters (Banglish), like the user');

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
