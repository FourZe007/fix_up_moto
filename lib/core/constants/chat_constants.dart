/// Configuration for the chat with Fima, the app's virtual customer service.
///
/// This is a **separate backend** from [ApiConstants.baseUrl] — its own port,
/// plain JSON (no SAMP envelope), and no member identity: it is asked a
/// question and answers it, with no memory of the one before.
class ChatConstants {
  ChatConstants._(); // static-only class — never instantiated

  /// POST — body: `{ "question": "<text>" }`, JSON.
  ///
  /// Answers `200` with `{ "message": "<answer>", "status": true }`. The answer
  /// is plain text, paragraphs separated by `\n\n`. When it has nothing useful
  /// to say it still answers `status: true`, with an apology as the message —
  /// to the data layer that is an answer like any other, not an error; the
  /// repository recognises it (isFimaApology) and tries [knowledgeAsset].
  ///
  /// `status: false` (also with `200`) is a refusal, with its reason as the
  /// message — an empty question, for one. Anything that goes wrong inside the
  /// service comes back as an HTML `500` page, not JSON.
  ///
  /// An absolute URL, since the host's port differs from the rest of the API:
  /// Dio uses it as is, ignoring its base URL.
  static const String askUrl =
      'https://wsip.yamaha-jatim.co.id:5000/api/chat/fixupmoto';

  /// The markdown file Fima answers from when the service apologises — topics
  /// with their keywords and answers (see KnowledgeBase for the format). Must
  /// match an entry under `flutter: assets:` in pubspec.yaml.
  static const String knowledgeAsset = 'assets/knowledge/fima_knowledge.md';

  /// The longest question the service survives, in characters as Dart counts
  /// them (UTF-16 units; an emoji is two).
  ///
  /// Checked against the live service on 2026-10-20: a question of 100
  /// characters is answered and one of 101 crashes it with an HTML `500`, for
  /// any text; accented letters are no different, and a question of 98 units
  /// made mostly of emoji is fine. So the composer stops here, rather than let
  /// the member send what is certain to fail. Raise it if the service's limit
  /// is ever raised.
  static const int maxMessageLength = 100;

  /// How long to wait for an answer before giving up. Answers take 1 to 5
  /// seconds when the service is well; this leaves room for it to be slow
  /// without leaving the member watching dots for ever.
  static const Duration replyTimeout = Duration(seconds: 45);
}
