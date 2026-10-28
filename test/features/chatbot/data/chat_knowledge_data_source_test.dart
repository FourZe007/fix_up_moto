import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/constants/chat_constants.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_knowledge_data_source.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/knowledge_base.dart';

/// A bundle holding just the files it was given.
class _FakeBundle extends CachingAssetBundle {
  final Map<String, String> files;

  _FakeBundle(this.files);

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetChatKnowledgeDataSource', () {
    test('reads the file at the path it is given, accents and all', () async {
      final source = AssetChatKnowledgeDataSource(
        bundle: _FakeBundle({'k.md': '## Poin\nKata kunci: poin\nÉcole ✓'}),
        path: 'k.md',
      );

      expect(await source.load(), '## Poin\nKata kunci: poin\nÉcole ✓');
    });

    test('reads the app\'s own knowledge file by default', () async {
      final source = AssetChatKnowledgeDataSource(
        bundle: _FakeBundle({ChatConstants.knowledgeAsset: 'isi'}),
      );

      expect(await source.load(), 'isi');
    });

    test('throws when the file is not there, for the repository to cope', () {
      final source = AssetChatKnowledgeDataSource(bundle: _FakeBundle({}));

      expect(source.load(), throwsA(isA<FlutterError>()));
    });
  });

  // Guards the real file against a slip while it is being written: a section
  // that is skipped because of a typo would otherwise fail silently, as Fima
  // simply not knowing the topic.
  group('the bundled knowledge file', () {
    late String text;

    setUpAll(() async {
      text = await AssetChatKnowledgeDataSource().load();
    });

    test('is declared in pubspec and can be read', () {
      expect(text, isNotEmpty);
    });

    test('has every section it writes understood: none is skipped', () {
      final written = RegExp(
        r'^##\s',
        multiLine: true,
      ).allMatches(text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')).length;

      final understood = KnowledgeBase.parse(text).entries;

      expect(
        understood,
        hasLength(written),
        reason:
            'a "## " section has no "Kata kunci:" line, no keywords or no '
            'answer, so Fima would silently ignore it',
      );
    });

    test('gives no two topics the same keyword, so the first never hides '
        'the second', () {
      final seen = <String, String>{};
      for (final entry in KnowledgeBase.parse(text).entries) {
        for (final keyword in entry.keywords) {
          expect(
            seen[keyword],
            isNull,
            reason:
                '"$keyword" is a keyword of both "${seen[keyword]}" and '
                '"${entry.title}"',
          );
          seen[keyword] = entry.title;
        }
      }
    });
  });
}
