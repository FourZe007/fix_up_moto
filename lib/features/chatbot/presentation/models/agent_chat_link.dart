import 'package:fix_up_moto/core/constants/app_constants.dart';

/// What the member's WhatsApp opens with when they ask a person for help: a
/// greeting and, when there is one, the question Fima could not answer. Only
/// that — the member reads it, and sends it themselves.
String agentChatMessage([String? question]) {
  const greeting = 'Halo FixUp Moto, saya butuh bantuan.';

  final asked = question?.trim() ?? '';
  return asked.isEmpty ? greeting : '$greeting Pertanyaan saya: "$asked"';
}

/// The customer service's WhatsApp chat ([AppConstants.whatsappServiceUrl])
/// with [agentChatMessage] typed in. Spaces are `%20`, which WhatsApp's own
/// links use, rather than the `+` a query string would give them.
String agentChatUrl([String? question]) =>
    '${AppConstants.whatsappServiceUrl}'
    '?text=${Uri.encodeComponent(agentChatMessage(question))}';
