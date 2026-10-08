/// Utility class for consistent text casing throughout the app.
///
/// All methods are static — import and call directly:
///   `TextFormatter.fromUppercase('GRATIS GANTI OLI')` → "Gratis Ganti Oli"
///
/// The SAMP backend sends many names shouted in capitals; formatting them here,
/// at display time, keeps the data as the server sent it (ids, comparisons and
/// request bodies still see the original) and the casing rule in one place.
class TextFormatter {
  TextFormatter._(); // static-only class

  /// One word: a run of letters (any script), with apostrophes kept inside it so
  /// "MOTOR'S" is a single word rather than "MOTOR" and "S".
  static final RegExp _word = RegExp(r"\p{L}+(?:['’]\p{L}+)*", unicode: true);

  /// Turns every ALL-UPPERCASE word in [text] into one with only its first
  /// letter uppercase:
  ///
  /// ```
  /// 'GRATIS GANTI OLI'                   → 'Gratis Ganti Oli'
  /// 'DISKON JASA SERVICE Rp. 20.000,00'  → 'Diskon Jasa Service Rp. 20.000,00'
  /// ```
  ///
  /// Only words with no lowercase letter are touched. A word that already
  /// mixes cases ("Rp", "iPhone", "Oli") was cased on purpose and is left as it
  /// is, which is why the "Rp." above survives. Digits, punctuation and
  /// whitespace are never changed, so the text keeps its exact layout.
  ///
  /// An acronym written in capitals ("CVT") is indistinguishable from a
  /// shouted word and becomes "Cvt".
  static String fromUppercase(String text) {
    return text.replaceAllMapped(_word, (match) {
      final word = match[0]!;

      // Has a lowercase letter somewhere: not shouted, leave it alone.
      if (word != word.toUpperCase()) return word;

      // Split by code point, not by UTF-16 unit, so a letter outside the basic
      // plane is never cut in half.
      final letters = word.runes.toList();
      final first = String.fromCharCode(letters.first);
      final rest = String.fromCharCodes(letters.skip(1));
      return first + rest.toLowerCase();
    });
  }
}
