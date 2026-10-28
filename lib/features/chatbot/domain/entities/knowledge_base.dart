import 'package:equatable/equatable.dart';

/// One topic Fima can answer from the knowledge file.
class KnowledgeEntry extends Equatable {
  /// The section's heading. Only for people reading the file and the tests.
  final String title;

  /// What a question has to contain for this topic to apply, already in the
  /// form [KnowledgeBase] compares (lower case, no punctuation).
  final List<String> keywords;

  /// What Fima says, exactly as written in the file.
  final String answer;

  const KnowledgeEntry({
    required this.title,
    required this.keywords,
    required this.answer,
  });

  @override
  List<Object> get props => [title, keywords, answer];
}

/// The topics Fima answers herself, read from a markdown file, for the
/// questions the chat service apologises for.
///
/// The file is a list of `##` sections. Each holds a `Kata kunci:` line (words
/// or phrases, comma separated) and, after it, the answer:
///
/// ```
/// ## Poin
/// Kata kunci: poin, point, tukar poin
/// Poin didapat dari setiap servis…
/// ```
///
/// A section without keywords or without an answer is skipped, and `<!-- -->`
/// comments are dropped, so notes and unfinished sections never reach a member.
/// Answers are shown as plain text: no markdown formatting inside them.
class KnowledgeBase {
  final List<KnowledgeEntry> entries;

  const KnowledgeBase(this.entries);

  /// Knows nothing: every question gets no answer.
  static const empty = KnowledgeBase([]);

  /// Reads [markdown] in the format above. Never throws: whatever cannot be
  /// understood is skipped.
  factory KnowledgeBase.parse(String markdown) {
    final lines = markdown
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll('\r\n', '\n')
        .split('\n');

    final entries = <KnowledgeEntry>[];
    String? title;
    var body = <String>[];

    void finish() {
      final entry = title == null ? null : _entryFrom(title, body);
      if (entry != null) entries.add(entry);
    }

    for (final line in lines) {
      final heading = _heading.firstMatch(line);
      if (heading == null) {
        body.add(line);
        continue;
      }

      finish();
      // `##` starts a topic; a `#` title (or anything else above the first
      // topic) belongs to nobody and is skipped.
      title = heading.group(1) == '##' ? heading.group(2)!.trim() : null;
      body = <String>[];
    }
    finish();

    return KnowledgeBase(List.unmodifiable(entries));
  }

  /// Fima's answer to [question] from this file, or null when it has none.
  ///
  /// The topic with the most of its keywords in the question wins; on a tie the
  /// one written first. A keyword counts only as whole words, so "poin" is not
  /// found in "kepoin".
  String? answerFor(String question) {
    final words = ' ${normalise(question)} ';

    KnowledgeEntry? best;
    var bestScore = 0;
    for (final entry in entries) {
      final score = entry.keywords.where((k) => words.contains(' $k ')).length;
      if (score > bestScore) {
        best = entry;
        bestScore = score;
      }
    }
    return best?.answer;
  }

  /// Lower case, with every run of anything that is not a letter or digit
  /// turned into one space — so "Poin?" and "poin" are the same word.
  static String normalise(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();

  /// `#` or `##` at the start of a line, then a space and the heading's words.
  /// Deeper headings (`###`) and a `#hashtag` are ordinary text.
  static final _heading = RegExp(r'^(##?)\s+(.*)$');

  static final _keywordLine = RegExp(
    r'^\s*kata kunci\s*:(.*)$',
    caseSensitive: false,
  );

  static KnowledgeEntry? _entryFrom(String title, List<String> body) {
    final at = body.indexWhere(_keywordLine.hasMatch);
    if (at < 0) return null;

    final keywords = [
      for (final keyword
          in _keywordLine.firstMatch(body[at])!.group(1)!.split(','))
        if (normalise(keyword).isNotEmpty) normalise(keyword),
    ];
    final answer = body.skip(at + 1).join('\n').trim();
    if (keywords.isEmpty || answer.isEmpty) return null;

    return KnowledgeEntry(
      title: title,
      keywords: List.unmodifiable(keywords),
      answer: answer,
    );
  }
}
