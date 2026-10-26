import 'dart:convert';

import 'package:flutter/painting.dart';

/// What to draw for a bike's `photo` string, or `null` when there is nothing
/// to draw.
///
/// `BikeModel.photo` has only ever come back empty in the real responses seen
/// so far, so which format a real value would use — a URL or base64 — isn't
/// confirmed; both are supported rather than guessing wrong. A base64 value may
/// arrive bare or as a `data:image/...;base64,` data URI, so the scheme prefix
/// (if any) is stripped before decoding.
///
/// Null means either there is no photo, or the string wasn't a URL and wasn't
/// valid base64 either — both are treated as "no photo" by callers.
///
/// Shared by My Bikes' card thumbnail and the bike form's photo box, so the two
/// can never disagree about what a stored photo looks like.
ImageProvider? bikePhotoProvider(String photo) {
  final trimmed = photo.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return NetworkImage(trimmed);
  }

  final raw = trimmed.contains(',')
      ? trimmed.substring(trimmed.indexOf(',') + 1)
      : trimmed;
  try {
    return MemoryImage(base64Decode(raw));
  } on FormatException {
    return null;
  }
}
