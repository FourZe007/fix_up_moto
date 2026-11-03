import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/otp/domain/otp_code_generator.dart';

/// Always draws the same digit.
class _FixedRandom implements Random {
  final int value;

  _FixedRandom(this.value);

  @override
  int nextInt(int max) => value;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  test('a code is six digits long', () {
    expect(OtpCodeGenerator.length, 6);

    final generator = OtpCodeGenerator();
    for (var i = 0; i < 200; i++) {
      expect(generator.generate(), matches(RegExp(r'^\d{6}$')));
    }
  });

  test('keeps leading zeros: a code is text, not a number', () {
    expect(OtpCodeGenerator(random: _FixedRandom(0)).generate(), '000000');
    expect(OtpCodeGenerator(random: _FixedRandom(7)).generate(), '777777');
  });

  test('does not hand out the same code every time', () {
    final generator = OtpCodeGenerator();

    final codes = {for (var i = 0; i < 20; i++) generator.generate()};

    // Twenty identical six-digit codes in a row would be a one-in-10^114 event.
    expect(codes.length, greaterThan(1));
  });
}
