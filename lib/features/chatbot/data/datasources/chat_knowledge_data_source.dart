import 'package:flutter/services.dart';
import 'package:fix_up_moto/core/constants/chat_constants.dart';

/// Where Fima's own knowledge comes from: the text of the markdown file she
/// answers from when the chat service cannot (parsed by KnowledgeBase).
abstract class ChatKnowledgeDataSource {
  /// The file's text. Throws when it cannot be read; the repository then goes
  /// on as if there were no file.
  Future<String> load();
}

/// Reads the file bundled with the app ([ChatConstants.knowledgeAsset]).
class AssetChatKnowledgeDataSource implements ChatKnowledgeDataSource {
  final AssetBundle _bundle;
  final String _path;

  /// [bundle] and [path] are for tests.
  AssetChatKnowledgeDataSource({AssetBundle? bundle, String? path})
    : _bundle = bundle ?? rootBundle,
      _path = path ?? ChatConstants.knowledgeAsset;

  @override
  Future<String> load() => _bundle.loadString(_path);
}
