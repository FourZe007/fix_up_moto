import 'package:flutter/services.dart';

import 'package:fix_up_moto/core/helpers/phone_number.dart';

/// Keeps a phone field holding just the subscriber number (`81234567890`) while
/// the member types or pastes.
///
/// For a field that shows a fixed `+62` in front of the text: whatever else
/// the member writes — the trunk `0` of `0812…`, a `62` or `+62`, spaces and
/// dashes — is already implied or is only decoration, so it is dropped on the
/// way in instead of ending up as `+62 0812…` or `+62 +62812…`. It is the same
/// rule the backend request applies ([PhoneNumber.toSubscriberNumber]), only
/// applied earlier so the screen shows what will be sent.
class PhoneNumberInputFormatter extends TextInputFormatter {
  const PhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = PhoneNumber.toSubscriberNumber(newValue.text);
    if (cleaned == newValue.text) return newValue;

    // Keep the cursor where the member left it, less the characters dropped
    // (the paste of "+62 812…" should end after the digits, not at some
    // offset past them), rather than jumping to the end on every edit.
    final dropped = newValue.text.length - cleaned.length;
    final offset = newValue.selection.isValid
        ? (newValue.selection.extentOffset - dropped).clamp(0, cleaned.length)
        : cleaned.length;

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
