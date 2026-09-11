/// Configuration for the Instagram feed proxy.
///
/// This is a **separate backend** from [ApiConstants.baseUrl] — a small
/// standalone Vercel function that holds the Meta Business System User token
/// server-side, polls the Instagram Graph API on its own schedule, and
/// re-exposes the result in this app's own shape. The Flutter app never talks
/// to Meta directly and never holds any Meta credential.
class FeedConstants {
  FeedConstants._(); // static-only class — never instantiated

  /// GET — returns `{ "posts": [ { id, caption, mediaType, mediaUrl,
  /// thumbnailUrl, permalink, timestamp }, ... ] }`.
  static const String instagramFeedUrl =
      'https://fixupmoto-proxy.vercel.app/api/feed/ig';
}
