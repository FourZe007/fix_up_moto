/// Whether [answer] is the chat service saying it has nothing to say.
///
/// The service has no way to report "I cannot answer that": it replies
/// `status: true` with an apology as the message (see ChatConstants.askUrl), so
/// the only way to tell is by its words. The one wording on record is "Mohon
/// Maaf untuk saat ini saya belum bisa menjawab pertanyaan anda."; add any other
/// the service is seen to use to [_signs].
///
/// This is the one rule for "Fima could not answer": the repository uses it to
/// reach for the knowledge file, and the chat to offer a person to talk to.
bool isFimaApology(String answer) {
  final text = answer.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  return _signs.any((words) => words.every(text.contains));
}

/// Each entry is a set of words that, all present, mark an apology.
const _signs = [
  // The recorded wording.
  ['belum bisa menjawab'],
  // The same apology in other words: "Maaf, saya tidak dapat menjawab …".
  ['maaf', 'menjawab'],
];
