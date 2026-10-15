import 'package:equatable/equatable.dart';

/// What a notification's link leads to; decides how its button reads.
enum LinkKind {
  /// A Google Form the member is asked to fill in.
  googleForm,

  /// Any other web page.
  other,
}

/// A notification's link, when it is a web address worth a button.
///
/// The backend sends blank or `-` for a message with no link, and only
/// `http(s)` addresses are opened, so [tryParse] turns everything else into
/// null.
class NotificationLink extends Equatable {
  final Uri uri;
  final LinkKind kind;

  const NotificationLink._(this.uri, this.kind);

  /// The link exactly as the backend sent it, or null when there is nothing to
  /// open.
  static NotificationLink? tryParse(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    return NotificationLink._(uri, _kindOf(uri));
  }

  /// Google Forms live on the `forms.gle` short links and under
  /// `docs.google.com/forms/...` (also behind `/u/0/` or `/a/<domain>/`).
  /// [Uri.host] is already lower case.
  static LinkKind _kindOf(Uri uri) {
    final isGoogleForm =
        uri.host == 'forms.gle' ||
        uri.host == 'forms.google.com' ||
        (uri.host == 'docs.google.com' && uri.path.contains('/forms/'));

    return isGoogleForm ? LinkKind.googleForm : LinkKind.other;
  }

  @override
  List<Object> get props => [uri, kind];
}
