import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';

/// The text a reel is shared as: just the link to the original Instagram post.
///
/// The link is the post's `permalink` — a public page that opens for anyone —
/// and never `mediaUrl`, which is a temporary file link that expires. The
/// caption is deliberately not included.
///
/// Returns an empty string when the post has no link, so the caller can skip
/// sharing nothing.
String reelShareText(FeedEntity post) => post.permalink.trim();
