import 'package:equatable/equatable.dart';

/// One backend flag as the two checkboxes the filter panel shows for it: a
/// "yes" box (e.g. Terkirim, Sudah dibaca) and a "no" box (Belum terkirim,
/// Belum dibaca).
///
/// The backend takes the flag as a single string, so the two boxes collapse
/// into it: only "yes" ticked sends `"1"`, only "no" ticked sends `"0"`, and
/// both or neither ticked sends `""` — no filter on that flag, so both kinds
/// come back. (`"0"` is the presumed value for "no"; it is not confirmed
/// against the backend yet.)
class FlagChoice extends Equatable {
  /// The "yes" checkbox (e.g. sent, read).
  final bool yes;

  /// The "no" checkbox (e.g. not sent, unread).
  final bool no;

  const FlagChoice({required this.yes, required this.no});

  /// Both ticked: no filter on this flag.
  static const FlagChoice both = FlagChoice(yes: true, no: true);

  /// The string the backend filter takes: `"1"`, `"0"` or `""`.
  String get apiValue => yes == no ? '' : (yes ? '1' : '0');

  FlagChoice copyWith({bool? yes, bool? no}) =>
      FlagChoice(yes: yes ?? this.yes, no: no ?? this.no);

  @override
  List<Object> get props => [yes, no];
}

/// What the inbox is filtered by: whether messages were sent, and whether they
/// were read. [defaults] is the whole sent inbox — the same as the backend
/// call's own defaults (`IsSent: "1"`, `IsRead: ""`).
class NotificationFilter extends Equatable {
  final FlagChoice sent;
  final FlagChoice read;

  const NotificationFilter({required this.sent, required this.read});

  /// Messages already sent, read or unread.
  static const NotificationFilter defaults = NotificationFilter(
    sent: FlagChoice(yes: true, no: false),
    read: FlagChoice.both,
  );

  /// The `IsSent` value to send.
  String get isSent => sent.apiValue;

  /// The `IsRead` value to send.
  String get isRead => read.apiValue;

  bool get isDefault => this == defaults;

  NotificationFilter copyWith({FlagChoice? sent, FlagChoice? read}) =>
      NotificationFilter(sent: sent ?? this.sent, read: read ?? this.read);

  @override
  List<Object> get props => [sent, read];
}
