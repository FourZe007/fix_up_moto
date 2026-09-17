import 'package:flutter/material.dart';

/// AI-powered virtual customer service chat — placeholder for now.
///
/// Deliberately empty (no BLoC, data, or domain layers yet): the Home button
/// and route wiring are being built first so navigation works end to end,
/// with the actual chat feature coming after the app's other main features
/// are finished.
class ChatbotPage extends StatelessWidget {
  const ChatbotPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with Mika')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined, size: 48),
            SizedBox(height: 12),
            Text('Coming soon'),
          ],
        ),
      ),
    );
  }
}
