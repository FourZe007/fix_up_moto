import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';

/// A stand-in for the OTP page, for testing the screens that open it.
///
/// Add [route] to the test's router. It records the [OtpRequest] it was opened
/// with and closes with whatever the test taps: [correct] pops `true`, as the
/// real page does when the right code is typed, and [cancel] pops `false`, as
/// backing out does.
class OtpStandIn {
  /// Every request the page was opened with, in order.
  final List<OtpRequest> opened = [];

  static final Finder correct = find.text('Kode benar');
  static final Finder cancel = find.text('Batal');

  GoRoute get route => GoRoute(
    path: RouteNames.otp,
    builder: (_, state) =>
        _StandInPage(request: state.extra as OtpRequest, onOpened: opened.add),
  );
}

class _StandInPage extends StatefulWidget {
  final OtpRequest request;
  final void Function(OtpRequest request) onOpened;

  const _StandInPage({required this.request, required this.onOpened});

  @override
  State<_StandInPage> createState() => _StandInPageState();
}

class _StandInPageState extends State<_StandInPage> {
  @override
  void initState() {
    super.initState();
    // Once per opening, not once per rebuild.
    widget.onOpened(widget.request);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('Kode benar'),
          ),
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }
}
