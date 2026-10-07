import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fix_up_moto/core/constants/asset_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/refresh/refresh_on.dart';
import 'package:fix_up_moto/core/services/screen_brightness_booster.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';

/// Loyalty status: points, point-earning history, and vouchers.
///
/// **No new domain or data layer needed.** [DashboardStatsEntity] — already
/// fetched by [HomeBloc] for Home's greeting header — already carries
/// `point`, `detail` (point history), and `detail2` (vouchers). This page
/// gets its own [HomeBloc] instance and fires its own fetch on mount, the
/// same page-scoped-factory pattern every tab uses, rather than sharing
/// Home's instance — the two tabs' data lifecycles are independent even
/// though the shape is identical.
class MembershipPage extends StatelessWidget {
  const MembershipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeBloc>()..add(const HomeStatsRequested()),
      child: const _MembershipView(),
    );
  }
}

class _MembershipView extends StatelessWidget {
  const _MembershipView();

  @override
  Widget build(BuildContext context) {
    // This tab stays alive while hidden, so it reloads when something that
    // changes the stats happens elsewhere (e.g. a bike is added).
    return RefreshOn(
      kind: DataKind.stats,
      onRefresh: (context) =>
          context.read<HomeBloc>().add(const HomeStatsRequested()),
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('My Point'),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.primary),
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            return switch (state) {
              HomeInitial() || HomeLoading() => const Center(
                child: Column(
                  spacing: 20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.backgroundLight),

                    Text(
                      'Loading...',
                      style: TextStyle(color: AppColors.backgroundLight),
                    ),
                  ],
                ),
              ),
              HomeError(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<HomeBloc>().add(
                        const HomeStatsRequested(),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              HomeLoaded(:final stats) => _MembershipBody(stats: stats),
            };
          },
        ),
      ),
    );
  }
}

// ── Point card finish ───────────────────────────────────────────────────────
// A satin look: a soft tonal base with glossy diagonal bands over it. Built from
// tints of AppColors.primaryLight (10% / 30% / 40% over white) so it stays in
// the palette while the page behind stays the saturated brand orange.

/// Layer 1: cream (top-left) → peach (bottom-right).
const _satinBase = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFCDAC), Color(0xFFFFDAC1), Color(0xFFFFCDAC)],
  stops: [0.0, 0.55, 1.0],
);

/// Layer 2: two soft white bands slanted along the card, fading in and out —
/// the "light catching the surface" streaks. Every colour is white (only the
/// alpha changes) so the fade never turns grey.
const _satinSheen = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0x00FFFFFF),
    Color(0x8CFFFFFF),
    Color(0x00FFFFFF),
    Color(0x00FFFFFF),
    Color(0x59FFFFFF),
    Color(0x00FFFFFF),
  ],
  stops: [0.12, 0.22, 0.34, 0.52, 0.62, 0.74],
);

/// A centred popup rather than a pushed route: showing a code is a quick,
/// in-context step, and tapping outside it (or its X) is the way back.
void _showMemberQr(BuildContext context, DashboardStatsEntity stats) {
  showDialog<void>(
    context: context,
    builder: (_) =>
        _MemberQrDialog(memberId: stats.memberId, memberName: stats.memberName),
  );
}

/// The enlarged member QR, with the screen at full brightness while it is open.
///
/// Brightness is raised in [initState] and restored in [dispose], so every way
/// of closing the popup (tap outside, X button, back button, a pop from code)
/// puts it back — there is no close path to forget.
class _MemberQrDialog extends StatefulWidget {
  final String memberId;
  final String memberName;

  const _MemberQrDialog({required this.memberId, required this.memberName});

  @override
  State<_MemberQrDialog> createState() => _MemberQrDialogState();
}

class _MemberQrDialogState extends State<_MemberQrDialog> {
  static const double _logoSize = 48;
  static const double _qrSize = 240;

  final ScreenBrightnessBooster _brightness = sl<ScreenBrightnessBooster>();

  @override
  void initState() {
    super.initState();
    // Never throws (it swallows its own errors), so it is safe to not await.
    _brightness.boost();
  }

  @override
  void dispose() {
    _brightness.restore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Scrolls instead of overflowing on a short screen or a large font.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('member-qr-close'),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            // The logo lives here now (it used to be the card's badge). The
            // JPEG carries its own red square, so it is just clipped rounded.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                AssetConstants.logo,
                key: const Key('member-qr-logo'),
                width: _logoSize,
                height: _logoSize,
                fit: BoxFit.cover,
                // 1600x1600 (~10 MB decoded) — decode it at the size it is
                // shown instead.
                cacheWidth: (_logoSize * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                semanticLabel: 'FixUp Moto',
                errorBuilder: (_, _, _) => Container(
                  width: _logoSize,
                  height: _logoSize,
                  color: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.card_membership,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.memberName,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Always dark on white, whatever the app theme: that is what
            // scanners read best.
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey200),
              ),
              child: QrImageView(
                // The payload is the raw member ID and nothing else (no prefix,
                // no URL): whatever scans this has to expect exactly that.
                data: widget.memberId,
                size: _qrSize,
                backgroundColor: Colors.white,
                // M (not the default L) survives a scuffed or glared screen.
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
                semanticsLabel: 'Member QR code',
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.memberId, style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Tunjukkan kode ini di bengkel terdekat',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _MembershipTab { history, vouchers }

/// The rounded box under the point card: two tabs fixed at its top, and the
/// chosen tab's entries below as rounded cards. Only the list scrolls, so the
/// tabs never move.
///
/// Which tab is open is plain UI state, so it lives here rather than in a BLoC.
/// It survives the page's data reloads (the same State is kept while the stats
/// change underneath it).
class _HistoryVouchersBox extends StatefulWidget {
  final DashboardStatsEntity stats;

  const _HistoryVouchersBox({required this.stats});

  @override
  State<_HistoryVouchersBox> createState() => _HistoryVouchersBoxState();
}

class _HistoryVouchersBoxState extends State<_HistoryVouchersBox> {
  _MembershipTab _tab = _MembershipTab.history;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Keeps the scrolling cards inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: _TabPill(
                    key: const Key('tab-history'),
                    label: 'Riwayat Point',
                    selected: _tab == _MembershipTab.history,
                    onTap: () => setState(() => _tab = _MembershipTab.history),
                  ),
                ),
                Expanded(
                  child: _TabPill(
                    key: const Key('tab-vouchers'),
                    label: 'Voucher',
                    selected: _tab == _MembershipTab.vouchers,
                    onTap: () => setState(() => _tab = _MembershipTab.vouchers),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              // Pinned to the top, so a short list or an empty message starts
              // right under the tabs instead of floating in the middle.
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: switch (_tab) {
                _MembershipTab.history => _PointHistoryList(
                  key: const ValueKey(_MembershipTab.history),
                  entries: widget.stats.detail,
                ),
                _MembershipTab.vouchers => _VoucherList(
                  key: const ValueKey(_MembershipTab.vouchers),
                  vouchers: widget.stats.detail2,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two tabs: filled when selected, outlined when not.
class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Color(0xFFFFCDAC), width: selected ? 0 : 1.5),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Color(0xFFFFCDAC) : Colors.transparent,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                // Dark red (not the orange) on the light box: it reads better.
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared look of a "display data" card: white (light grey in dark mode, via
/// [LightSurfaceScope]), rounded, with a hairline border, on the grey box.
class _EntryCard extends StatelessWidget {
  final Widget child;

  const _EntryCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return LightSurfaceScope(
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.grey200),
        ),
        child: child,
      ),
    );
  }
}

/// The scrolling body of a tab. Always a list (even when empty) so the page's
/// pull-to-refresh also works from inside the box.
class _TabList extends StatelessWidget {
  final List<Widget> children;

  const _TabList({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: children,
    );
  }
}

class _PointHistoryList extends StatelessWidget {
  final List<PointDetailEntity> entries;

  const _PointHistoryList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        alignment: Alignment.topCenter,
        margin: EdgeInsets.symmetric(vertical: 20),
        child: Text('Tidak ada riwayat point'),
      );
    }

    return _TabList(
      children: [
        for (final entry in entries)
          _EntryCard(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(entry.pointName),
              subtitle: Text(entry.transDate),
              trailing: Text(
                '+${entry.pointQty}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.green),
              ),
            ),
          ),
      ],
    );
  }
}

class _VoucherList extends StatelessWidget {
  final List<VoucherDetailEntity> vouchers;

  const _VoucherList({super.key, required this.vouchers});

  @override
  Widget build(BuildContext context) {
    if (vouchers.isEmpty) {
      return Container(
        alignment: Alignment.topCenter,
        margin: EdgeInsets.symmetric(vertical: 20),
        child: const Text('Tidak ada voucher tersedia'),
      );
    }

    return _TabList(
      children: [
        for (final voucher in vouchers)
          _EntryCard(
            child: ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: Text(voucher.voucherName),
              subtitle: Text(
                '${voucher.statusVoucherMemo} · expires ${voucher.expirationDate}',
              ),
              trailing: Text('Rp${voucher.voucherAmount.toStringAsFixed(0)}'),
            ),
          ),
      ],
    );
  }
}

class _MembershipBody extends StatelessWidget {
  final DashboardStatsEntity stats;

  const _MembershipBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    // RefreshIndicator reacts to a *scrollable* being pulled past its top — it
    // does nothing around a plain Column, which is why wrapping the two
    // widgets directly never refreshed. So the page is a CustomScrollView with
    // one sliver the exact height of the viewport (hasScrollBody: true, no
    // content measuring): nothing actually scrolls, but AlwaysScrollable lets
    // it be pulled, so pulling anywhere on the page — the balance card
    // included — refreshes.
    //
    // Inside it the balance card keeps its natural height and the box takes ALL
    // the remaining height (Expanded), so it runs down to the bottom of the
    // page. This page's body ends where MainShell's navigation bar begins, so
    // that is already just above the bar. Only the box's own list scrolls.
    return RefreshIndicator(
      // The box's list is a second Scrollable nested under the page's, so its
      // notifications arrive one level deeper; the default (depth 0 only) would
      // ignore pulls that start inside the box.
      notificationPredicate: (notification) => notification.depth <= 1,
      onRefresh: () async =>
          context.read<HomeBloc>().add(const HomeStatsRequested()),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  // ── Point balance card ──────────────────────────────────────────
                  // Cards are white in light mode, light grey in dark — see
                  // LightSurfaceScope. The Builder makes the text styles below come
                  // from the scoped theme, not from the outer `theme`.
                  Builder(
                    builder: (context) {
                      final cardTheme = Theme.of(context);

                      return Card(
                        margin: EdgeInsets.zero,
                        // Flat, like the Profile tiles: the page behind is
                        // orange, so the white card stands out without a shadow.
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: AppColors.backgroundLight,
                            width: 2,
                          ),
                          borderRadius: BorderRadiusGeometry.circular(20),
                        ),
                        child: Container(
                          width: double.infinity,
                          // A floor, not a fixed height: it grows with a larger
                          // system font instead of clipping.
                          constraints: const BoxConstraints(minHeight: 120),
                          // Satin finish: a soft cream → peach base (layer 1)
                          // with two diagonal glossy bands on top (layer 2).
                          // Both are tints of the brand orange, so the card
                          // reads as part of the palette, and the text on it is
                          // the brand's dark red. The card is clipped to its
                          // rounded shape by the Card around it.
                          decoration: const BoxDecoration(gradient: _satinBase),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: _satinSheen,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 32,
                              ),
                              child: Row(
                                spacing: 16,
                                children: [
                                  // Left: the quiet label with its QR icon, then
                                  // the balance as the one hero of the card.
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Point Saya',
                                          style: cardTheme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.3,
                                                // Brand dark red in light and dark
                                                // mode: it sits on the satin
                                                // card, not on the theme's card
                                                // colour.
                                                color: AppColors.primaryDark,
                                              ),
                                        ),

                                        // scaleDown: a very large balance shrinks
                                        // to fit the left side instead of
                                        // overflowing it.
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                '${stats.point}',
                                                style: cardTheme
                                                    .textTheme
                                                    .displayLarge
                                                    ?.copyWith(
                                                      fontSize: 52,
                                                      // Under 1.0 trims the empty
                                                      // line space above the
                                                      // digits (~8px), which is
                                                      // what the old -8 spacing
                                                      // was reaching for.
                                                      height: 0.9,
                                                      color:
                                                          AppColors.primaryDark,
                                                    ),
                                              ),
                                              // Same "pts" wording as Home's
                                              // greeting chip.
                                              Text(
                                                'pts',
                                                style: cardTheme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color:
                                                          AppColors.primaryDark,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Right: opens the member QR. The icon is only
                                  // a button — a QR this small could not be
                                  // scanned — so the real code is in the sheet.
                                  // Disabled without a member ID, so an empty
                                  // string is never encoded.
                                  IconButton(
                                    key: const Key('member-qr-button'),
                                    tooltip: 'Show my member QR',
                                    onPressed: stats.memberId.trim().isEmpty
                                        ? null
                                        : () => _showMemberQr(context, stats),
                                    icon: const Icon(
                                      Icons.qr_code_rounded,
                                      size: 40,
                                    ),
                                    style: IconButton.styleFrom(
                                      foregroundColor: AppColors.surfaceLight,
                                      backgroundColor: AppColors.primaryLight,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadiusGeometry.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Spacing
                  const SizedBox(height: 20),

                  // Tabs (Point History | Vouchers) fixed on top, the chosen tab's
                  // cards below, filling the rest of the page.
                  Expanded(child: _HistoryVouchersBox(stats: stats)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
