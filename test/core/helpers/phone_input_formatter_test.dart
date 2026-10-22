import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/phone_input_formatter.dart';

/// For a field with a fixed "+62" in front, so what is typed after it must be
/// the bare subscriber number — not "+62 0812…" or "+62 +62812…".
void main() {
  const formatter = PhoneNumberInputFormatter();
  const expected = '81234567890';

  /// [typed] arriving in an empty field with the cursor after it, as a paste or
  /// the first keystrokes would.
  TextEditingValue arrives(String typed) => formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: typed,
      selection: TextSelection.collapsed(offset: typed.length),
    ),
  );

  group('what ends up in the field', () {
    test('drops the trunk zero of 0812…', () {
      expect(arrives('081234567890').text, expected);
    });

    test('drops a pasted +62', () {
      expect(arrives('+6281234567890').text, expected);
    });

    test('drops a pasted bare 62', () {
      expect(arrives('6281234567890').text, expected);
    });

    test('drops spaces and dashes', () {
      expect(arrives('+62 812-3456-7890').text, expected);
      expect(arrives('812 3456 7890').text, expected);
    });

    test('drops letters and symbols', () {
      expect(arrives('812a3456x7890!').text, expected);
    });

    test('swallows a lone leading 0, which the +62 already implies', () {
      expect(arrives('0').text, '');
      expect(arrives('00').text, '');
    });

    test('leaves an already-clean number as it is', () {
      expect(arrives(expected).text, expected);
    });

    test('keeps an empty field empty', () {
      expect(arrives('').text, '');
    });

    test('is idempotent: formatting its own output changes nothing', () {
      final once = arrives('+62 0812-3456-7890');
      final twice = formatter.formatEditUpdate(once, once);

      expect(twice.text, once.text);
      expect(twice.selection, once.selection);
    });
  });

  group('the cursor', () {
    test('stays put when nothing had to change', () {
      const value = TextEditingValue(
        text: '81234',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = formatter.formatEditUpdate(value, value);

      expect(result, value);
    });

    test('ends up after the digits of a pasted +62 number', () {
      final result = arrives('+62 812-3456-7890');

      expect(result.selection, const TextSelection.collapsed(offset: 11));
    });

    test('stays at the start when a 0 is typed in front', () {
      const old = TextEditingValue(
        text: '812',
        selection: TextSelection.collapsed(offset: 0),
      );
      const typed = TextEditingValue(
        text: '0812',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = formatter.formatEditUpdate(old, typed);

      expect(result.text, '812');
      expect(result.selection, const TextSelection.collapsed(offset: 0));
    });

    test('steps back by the one character dropped in the middle', () {
      const old = TextEditingValue(
        text: '81234',
        selection: TextSelection.collapsed(offset: 3),
      );
      const typed = TextEditingValue(
        text: '812a34',
        selection: TextSelection.collapsed(offset: 4),
      );

      final result = formatter.formatEditUpdate(old, typed);

      expect(result.text, '81234');
      expect(result.selection, const TextSelection.collapsed(offset: 3));
    });

    test('goes to the end when the incoming value has no cursor', () {
      // TextEditingValue's default selection is invalid (-1).
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '0812'),
      );

      expect(result.text, '812');
      expect(result.selection, const TextSelection.collapsed(offset: 3));
    });
  });
}
