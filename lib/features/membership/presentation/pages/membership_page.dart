import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fix_up_moto/core/constants/asset_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/helpers/text_formatter.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/refresh/refresh_on.dart';
import 'package:fix_up_moto/core/services/screen_brightness_booster.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/membership/domain/entities/reward_entity.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_bloc.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_event.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_state.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_bloc.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_event.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_state.dart';

/// Loyalty status: points, point-earning history, and the vouchers points can
/// be exchanged for.
///
/// The balance and point history need no data layer of their own:
/// [DashboardStatsEntity] — already fetched by [HomeBloc] for Home's greeting
/// header — carries `point` and `detail` (point history). This page gets its
/// own [HomeBloc] instance and fires its own fetch on mount, the same
/// page-scoped-factory pattern every tab uses, rather than sharing Home's
/// instance — the two tabs' data lifecycles are independent even though the
/// shape is identical.
///
/// The Voucher tab is the exception: its list is a separate API call
/// ([RewardsBloc]), fetched the first time that tab is shown, and its Klaim
/// buttons spend points through [RedeemBloc]. Both blocs are provided here,
/// above the stats `BlocBuilder`, because [HomeBloc] emits a loading state on
/// every refresh and that unmounts everything below it — a claim that finishes
/// meanwhile must still be reported and still reload the balance.
class MembershipPage extends StatelessWidget {
  const MembershipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<HomeBloc>()..add(const HomeStatsRequested()),
        ),
        // No initial event: the Voucher tab asks for its list when it first
        // appears (see _HistoryVouchersBoxState).
        BlocProvider(create: (_) => sl<RewardsBloc>()),
        // Idle until a Klaim is confirmed.
        BlocProvider(create: (_) => sl<RedeemBloc>()),
      ],
      child: const _MembershipView(),
    );
  }
}

class _MembershipView extends StatelessWidget {
  const _MembershipView();

  /// Reports how a claim ended. Lives here, not in the voucher list, because
  /// the list can be unmounted (the member switches tab, or the stats reload)
  /// before the server answers.
  void _onRedeemResult(BuildContext context, RedeemState state) {
    final messenger = ScaffoldMessenger.of(context);

    switch (state) {
      case RedeemSuccess(:final voucherName):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Voucher "${TextFormatter.fromUppercase(voucherName)}" '
              'berhasil diklaim',
            ),
          ),
        );
        // The points are spent: reload the balance (and so which vouchers are
        // still affordable) here, and on Home and Profile too.
        context.read<DataRefreshCubit>().invalidate(DataKind.stats);
      case RedeemFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
      case RedeemInitial() || RedeemInProgress():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // This tab stays alive while hidden, so it reloads when something that
    // changes the stats happens elsewhere (e.g. a bike is added).
    return BlocListener<RedeemBloc, RedeemState>(
      listener: _onRedeemResult,
      child: RefreshOn(
        kind: DataKind.stats,
        onRefresh: (context) =>
            context.read<HomeBloc>().add(const HomeStatsRequested()),
        child: _scaffold(),
      ),
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

            // The payload is the raw member ID and nothing else (no prefix,
            // no URL): whatever scans this has to expect exactly that.
            _QrFrame(data: widget.memberId, semanticsLabel: 'Member QR code'),
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

/// A QR code in the form scanners read best, shared by the member popup and the
/// voucher popup so the two can never drift apart.
///
/// Always dark on white, whatever the app theme. [data] is encoded as is.
class _QrFrame extends StatelessWidget {
  static const double _qrSize = 240;

  final String data;
  final String semanticsLabel;

  const _QrFrame({required this.data, required this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: QrImageView(
        data: data,
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
        semanticsLabel: semanticsLabel,
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
/// It does not survive a stats reload: [HomeBloc]'s loading state unmounts this
/// box, so the tab falls back to the one it opens on (Voucher).
class _HistoryVouchersBox extends StatefulWidget {
  final DashboardStatsEntity stats;

  const _HistoryVouchersBox({required this.stats});

  @override
  State<_HistoryVouchersBox> createState() => _HistoryVouchersBoxState();
}

class _HistoryVouchersBoxState extends State<_HistoryVouchersBox> {
  _MembershipTab _tab = _MembershipTab.vouchers;

  @override
  void initState() {
    super.initState();
    // The box opens on the Voucher tab, so its list is wanted straight away.
    if (_tab == _MembershipTab.vouchers) _loadVouchersOnce();
  }

  /// Asks for the voucher list the first time only — [RewardsBloc] outlives
  /// this box, so flipping between tabs (or a stats reload that rebuilds the
  /// box) reuses what is already loaded instead of fetching again.
  void _loadVouchersOnce() {
    final rewards = context.read<RewardsBloc>();
    if (rewards.state is RewardsInitial) {
      rewards.add(const RewardsRequested());
    }
  }

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
                    key: const Key('tab-vouchers'),
                    label: 'Voucher',
                    selected: _tab == _MembershipTab.vouchers,
                    onTap: () {
                      setState(() => _tab = _MembershipTab.vouchers);
                      _loadVouchersOnce();
                    },
                  ),
                ),
                Expanded(
                  child: _TabPill(
                    key: const Key('tab-history'),
                    label: 'Riwayat',
                    selected: _tab == _MembershipTab.history,
                    onTap: () => setState(() => _tab = _MembershipTab.history),
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
                _MembershipTab.vouchers => _VoucherList(
                  key: const ValueKey(_MembershipTab.vouchers),
                  balance: widget.stats.point,
                  owned: _ownedVouchers(),
                ),
                _MembershipTab.history => _PointHistoryList(
                  key: const ValueKey(_MembershipTab.history),
                  entries: widget.stats.detail,
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
            // On a narrow phone or with a large system font a label can be
            // wider than its pill: shrink it to fit instead of cutting it off.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  // Dark red (not the orange) on the light box: it reads better.
                  color: AppColors.textPrimary,
                ),
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
              // leading: const Icon(Icons.history),
              title: Text(TextFormatter.fromUppercase(entry.pointName)),
              subtitle: Text(entry.transDate),
              trailing: Text(
                entry.pointQty.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: entry.pointQty.toString().trim().contains('-')
                      ? Colors.red
                      : Colors.green,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            ),
          ),
      ],
    );
  }
}

/// The Voucher tab: what the member already holds ("Voucher Saya"), then the
/// vouchers points can be exchanged for, loaded by [RewardsBloc], in one
/// scrolling list.
///
/// The exchangeable vouchers are a single section. A voucher is *available*
/// when the member's [balance] covers its point cost and *unavailable* when it
/// does not; each card shows which (see [_VoucherCard]), and the order does the
/// rest: the available ones first, in the order the API gave, then the
/// unavailable ones, the nearest to affordable first.
class _VoucherList extends StatelessWidget {
  /// The member's current point balance, which decides the split.
  final int balance;

  /// Vouchers the member already holds, shown above the exchangeable ones as
  /// "Voucher Saya". Empty means the section is left out.
  final List<VoucherDetailEntity> owned;

  const _VoucherList({super.key, required this.balance, this.owned = const []});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RewardsBloc, RewardsState>(
      builder: (context, state) => switch (state) {
        RewardsInitial() || RewardsLoading() => Column(
          spacing: 20,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator(), Text('Loading...')],
        ),
        RewardsError(:final message) => LightSurfaceScope(
          child: Container(
            alignment: Alignment.topCenter,
            margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const Key('vouchers-retry'),
                  onPressed: () =>
                      context.read<RewardsBloc>().add(const RewardsRequested()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        RewardsLoaded(:final rewards) when rewards.isEmpty => Container(
          alignment: Alignment.topCenter,
          margin: const EdgeInsets.symmetric(vertical: 20),
          child: const Text('Tidak ada voucher tersedia'),
        ),
        RewardsLoaded(:final rewards) => _sections(
          context,
          available: [
            for (final reward in rewards)
              if (reward.pointQty <= balance) reward,
          ],
          unavailable: [
            for (final reward in rewards)
              if (reward.pointQty > balance) reward,
          ],
        ),
      },
    );
  }

  /// One list, so everything scrolls together under the fixed tabs.
  Widget _sections(
    BuildContext context, {
    required List<RewardEntity> available,
    required List<RewardEntity> unavailable,
  }) {
    return _TabList(
      children: [
        if (owned.isNotEmpty) ...[
          _SectionHeader(
            key: const Key('vouchers-owned-header'),
            'Voucher Saya (${owned.length})',
          ),
          _OwnedVoucherCarousel(vouchers: owned),
        ],
        _ExchangeHeader(
          key: const Key('vouchers-exchange-header'),
          balance: balance,
          claimable: available.length,
          locked: unavailable.length,
        ),
        for (final reward in [...available, ..._nearestFirst(unavailable)])
          _VoucherCard(
            reward: reward,
            balance: balance,
            onClaim: () => _confirmClaim(context, reward),
          ),
      ],
    );
  }

  /// [rewards] cheapest first — for vouchers the balance does not cover, that is
  /// the smallest shortfall first. Equal prices keep the API's order, which
  /// `List.sort` alone does not promise, so the cards never swap places between
  /// two rebuilds.
  List<RewardEntity> _nearestFirst(List<RewardEntity> rewards) {
    final indexed = rewards.indexed.toList()
      ..sort((a, b) {
        final byPrice = a.$2.pointQty.compareTo(b.$2.pointQty);
        return byPrice != 0 ? byPrice : a.$1.compareTo(b.$1);
      });
    return [for (final (_, reward) in indexed) reward];
  }

  /// Asks before spending points, then hands the claim to [RedeemBloc].
  ///
  /// Spending is not undoable from the app, so a mis-tap must not go straight
  /// through. The bloc is read *before* the dialog opens: it outlives this
  /// list, so the claim still goes out if the list is rebuilt meanwhile.
  Future<void> _confirmClaim(BuildContext context, RewardEntity reward) async {
    final redeem = context.read<RedeemBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Klaim voucher?'),
        content: Text(
          'Tukarkan ${reward.pointQty} pts untuk '
          '"${TextFormatter.fromUppercase(reward.pointName)}".\n'
          'Sisa point Anda: ${balance - reward.pointQty} pts.',
        ),
        actions: [
          TextButton(
            key: const Key('klaim-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            key: const Key('klaim-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ya, Klaim'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      redeem.add(
        RedeemRequested(pointId: reward.pointId, voucherName: reward.pointName),
      );
    }
  }
}

/// Title of one voucher section, sitting on the grey box above its cards.
///
/// Colours are fixed rather than read from the theme: the box is light grey in
/// dark mode too, where the theme's own text colour would be white on it.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Title of the one section of vouchers points can buy: the point balance on
/// the right, and under the title a line saying how many of them the balance
/// covers.
///
/// Colours are fixed for the same reason as in [_SectionHeader].
class _ExchangeHeader extends StatelessWidget {
  /// The member's point balance.
  final int balance;

  /// How many of the vouchers the balance covers...
  final int claimable;

  /// ...and how many it does not yet.
  final int locked;

  const _ExchangeHeader({
    super.key,
    required this.balance,
    required this.claimable,
    required this.locked,
  });

  String get _summary {
    if (claimable == 0) return 'Point Anda belum cukup untuk voucher mana pun';
    if (locked == 0) return 'Semua voucher dapat Anda tukarkan';
    return '$claimable bisa ditukar • $locked belum cukup';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tukar dengan Point',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$balance pts',
                key: const Key('vouchers-balance'),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          Text(
            _summary,
            key: const Key('vouchers-summary'),
            style: textTheme.bodySmall?.copyWith(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

/// A voucher points can buy, in two parts split by a dashed line. When the
/// member's balance covers it, the bottom holds the Klaim button:
///
/// ```
/// ┌────────────────────────────────┐
/// │ name                      ┌──┐ │   top: the name on the left,
/// │                           │🎁│ │        the voucher icon on the right
/// │                           └──┘ │
/// ├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
/// │ 50 pts                [ Klaim ]│   bottom: the price, and Klaim
/// └────────────────────────────────┘
/// ```
///
/// When it does not, the top is faded so the card reads as out of reach at a
/// glance, and the bottom shows how far off the member is instead of a Klaim
/// button that could only ever be off:
///
/// ```
/// ┌────────────────────────────────┐
/// │ name (faded)              ┌──┐ │
/// │                           └──┘ │
/// ├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
/// │ 250 pts          Kurang 130 pts│
/// │ ▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱ │   points collected so far
/// └────────────────────────────────┘
/// ```
class _VoucherCard extends StatelessWidget {
  final RewardEntity reward;

  /// The member's point balance, which decides which bottom the card has.
  final int balance;

  /// Called when the (enabled) Klaim button is pressed.
  final VoidCallback onClaim;

  const _VoucherCard({
    required this.reward,
    required this.balance,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final available = reward.pointQty <= balance;

    return _EntryCard(
      // A Builder so the text styles come from the theme _EntryCard scopes
      // around its child (the light one, even in dark mode), not from the outer
      // theme this method sees — otherwise the text would be white on white.
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          final pointsStyle = textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: available
                ? AppColors.primaryDark
                : AppColors.primaryDark.withValues(alpha: 0.5),
          );

          return Column(
            key: Key('voucher-card-${reward.pointId}'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top: name left, icon right ──────────────────────────────────
              Opacity(
                key: Key('voucher-top-${reward.pointId}'),
                opacity: available ? 1 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    spacing: 12,
                    children: [
                      // Takes all the width the icon leaves, so a long name
                      // wraps here instead of pushing the icon off the card.
                      Expanded(
                        child: Text(
                          // The backend sends names in capitals.
                          TextFormatter.fromUppercase(reward.pointName),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        key: Key('voucher-icon-${reward.pointId}'),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.card_giftcard,
                          size: 28,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _DashedDivider(key: Key('voucher-divider-${reward.pointId}')),

              // ── Bottom: Klaim, or how far off the member still is ───────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: available
                    ? _claimRow(pointsStyle)
                    : _shortfallRow(textTheme, pointsStyle),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _claimRow(TextStyle? pointsStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('${reward.pointQty} pts', style: pointsStyle),
        BlocBuilder<RedeemBloc, RedeemState>(
          builder: (context, state) {
            // One claim at a time: while any is on its way every Klaim is off,
            // so a second tap cannot spend the points twice.
            final claiming = state is RedeemInProgress;
            final claimingThis = claiming && state.pointId == reward.pointId;

            return ElevatedButton(
              key: Key('klaim-${reward.pointId}'),
              onPressed: claiming ? null : onClaim,
              style: ElevatedButton.styleFrom(
                // The theme's buttons are full-width; this one sits in the
                // card's bottom row and must size to its label.
                minimumSize: const Size(72, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: claimingThis
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Text('Klaim', style: TextStyle(fontSize: 14)),
            );
          },
        ),
      ],
    );
  }

  Widget _shortfallRow(TextTheme textTheme, TextStyle? pointsStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            Text('${reward.pointQty} pts', style: pointsStyle),
            // Takes the width the price leaves and wraps, so a narrow phone or
            // a large font never pushes it off the card.
            Expanded(
              child: Text(
                'Kurang ${reward.pointQty - balance} pts',
                key: Key('shortfall-${reward.pointId}'),
                textAlign: TextAlign.end,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey700,
                ),
              ),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: Key('progress-${reward.pointId}'),
            // The share of the price the member has already collected.
            value: reward.pointQty <= 0
                ? 0
                : (balance / reward.pointQty).clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            // Darker than the card's border, so the track still shows on the
            // light-grey card dark mode uses.
            backgroundColor: AppColors.grey400.withValues(alpha: 0.5),
            color: AppColors.primary,
            semanticsLabel: 'Point terkumpul $balance dari ${reward.pointQty}',
          ),
        ),
      ],
    );
  }
}

/// A thin dashed line across the full width of its parent — the tear-off line
/// between a voucher's details and what is under it (its Klaim button, or how
/// far off the member still is).
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 1.5,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.grey400
      ..strokeWidth = size.height;
    final y = size.height / 2;

    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      final end = x + _dash > size.width ? size.width : x + _dash;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  // Nothing about it ever changes.
  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}

// ── Voucher Saya (prototype) ─────────────────────────────────────────────────
// The vouchers the member already holds, shown above the claimable ones. This is
// a DESIGN PROTOTYPE: the section is fed by one made-up voucher, not by
// `stats.detail2`. Wiring it to the real list (and deleting the dummy) comes
// after the design is accepted.

/// Shows the made-up voucher. On in debug and profile builds so the design can
/// be judged by simply running the app, and never on in a release build. Set it
/// to `false` to hide the section. The page's tests turn it off so they see the
/// page as it really is.
@visibleForTesting
bool showDummyVoucher = !kReleaseMode;

/// Deliberately not a real voucher rule id (those look like "B01") and not a
/// real serial number, so it can never be mistaken for, or redeemed as, a real
/// voucher.
const String _dummyVoucherId = 'DUMMY';
const String _dummyVoucherNo = 'DUMMY-DEMO-0001';

/// Days until the made-up voucher expires. Set it to 7 or less to preview the
/// "Sisa N hari" warning on the card.
const int _dummyDaysLeft = 30;

/// A voucher is flagged as running out when this many days or fewer are left.
const int _expiringSoonDays = 7;

/// What "Voucher Saya" lists: nothing yet but the made-up voucher.
List<VoucherDetailEntity> _ownedVouchers() {
  if (!showDummyVoucher) return const [];

  final now = DateTime.now();
  return [
    VoucherDetailEntity(
      redeemDate: DateTimeFormatter.fromUtcToDate(now),
      expirationDate: DateTimeFormatter.fromUtcToDate(
        now.add(const Duration(days: _dummyDaysLeft)),
      ),
      voucherNo: _dummyVoucherNo,
      statusVoucher: 1,
      voucherId: _dummyVoucherId,
      voucherName: 'CONTOH DISKON JASA SERVICE Rp. 20.000,00',
      statusVoucherMemo: 'AKTIF',
      voucherAmount: 20000,
    ),
  ];
}

bool _isDummy(VoucherDetailEntity voucher) =>
    voucher.voucherId == _dummyVoucherId;

/// Whole days from today until [expiry]'s date; negative once it has passed.
int _daysUntil(DateTime expiry) {
  final now = DateTime.now();
  // UTC midnights, so a daylight-saving change can never make a day 23 hours.
  return DateTime.utc(
    expiry.year,
    expiry.month,
    expiry.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
}

/// "Berlaku s/d 15 Nov 2026", or "Sisa 3 hari" in the final week. Falls back to
/// the raw text when the server's date cannot be read.
({String label, bool urgent}) _expiryNote(VoucherDetailEntity voucher) {
  final expiry = DateTime.tryParse(voucher.expirationDate);
  if (expiry == null) {
    return (label: 'Berlaku s/d ${voucher.expirationDate}', urgent: false);
  }

  final daysLeft = _daysUntil(expiry);
  if (daysLeft <= _expiringSoonDays) {
    return (
      label: daysLeft <= 0 ? 'Berakhir hari ini' : 'Sisa $daysLeft hari',
      urgent: true,
    );
  }
  // Non-breaking spaces in the date, so in a narrow card the label wraps after
  // "s/d" and never between the day and the year.
  final date = DateTimeFormatter.toShortDate(expiry).replaceAll(' ', ' ');
  return (label: 'Berlaku s/d $date', urgent: false);
}

/// The member's vouchers as a row of cards that swipes sideways, so any number
/// of them take the height of one card and the sections below stay in reach.
/// A single voucher takes the full width instead of looking lost in a carousel.
class _OwnedVoucherCarousel extends StatelessWidget {
  final List<VoucherDetailEntity> vouchers;

  const _OwnedVoucherCarousel({required this.vouchers});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // More than one: leave a slice of the next card showing, which is what
        // tells the member the row swipes.
        final cardWidth = vouchers.length == 1
            ? constraints.maxWidth
            : constraints.maxWidth * 0.82;

        return SingleChildScrollView(
          key: const Key('vouchers-owned-carousel'),
          scrollDirection: Axis.horizontal,
          // Every card as tall as the tallest, whatever its name's length.
          child: IntrinsicHeight(
            child: Row(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final voucher in vouchers)
                  SizedBox(
                    width: cardWidth,
                    child: _OwnedVoucherCard(voucher: voucher),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One voucher the member holds, in the same two parts as [_VoucherCard] so the
/// tab reads as one family:
///
/// ```
/// ┌────────────────────────────────┐
/// │ [CONTOH]                  ┌──┐ │   top: name, icon on the right
/// │ Diskon Jasa Service …     │🎟│ │
/// │                           └──┘ │
/// ├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
/// │ Berlaku s/d 15 Nov [Tampilkan QR]
/// └────────────────────────────────┘   bottom: expiry, then the QR button
/// ```
///
/// Unlike [_VoucherCard] the icon box is solid brand colour: these are the
/// member's own, so they are the strongest thing on the tab.
class _OwnedVoucherCard extends StatelessWidget {
  final VoucherDetailEntity voucher;

  const _OwnedVoucherCard({required this.voucher});

  @override
  Widget build(BuildContext context) {
    final note = _expiryNote(voucher);

    return _EntryCard(
      // A Builder so the text styles come from the light theme _EntryCard
      // scopes around its child — see _VoucherCard.
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;

          return Column(
            key: Key('owned-voucher-${voucher.voucherNo}'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top: name left, icon right ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          if (_isDummy(voucher)) const _DummyChip(),
                          Text(
                            // The backend sends names in capitals.
                            TextFormatter.fromUppercase(voucher.voucherName),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.confirmation_number_outlined,
                        size: 24,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const _DashedDivider(),

              // ── Bottom: expiry left, QR button right ────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        note.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: note.urgent
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: note.urgent
                              ? AppColors.error
                              : AppColors.grey600,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      key: Key('owned-voucher-qr-${voucher.voucherNo}'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _VoucherQrDialog(voucher: voucher),
                      ),
                      style: ElevatedButton.styleFrom(
                        // The theme's buttons are full-width; this one sits in
                        // the card's bottom row and must size to its label.
                        minimumSize: const Size(72, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text(
                        'Tampilkan QR',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The "CONTOH" (example) tag that marks the made-up voucher wherever it shows.
class _DummyChip extends StatelessWidget {
  const _DummyChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dummy-voucher-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'CONTOH',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
        ),
      ),
    );
  }
}

/// The enlarged voucher QR for the store admin, with the screen at full
/// brightness while it is open — the same popup as [_MemberQrDialog], for the
/// same reasons (see there): brightness is raised in [initState] and restored in
/// [dispose], so every way of closing the popup puts it back.
class _VoucherQrDialog extends StatefulWidget {
  final VoucherDetailEntity voucher;

  const _VoucherQrDialog({required this.voucher});

  @override
  State<_VoucherQrDialog> createState() => _VoucherQrDialogState();
}

class _VoucherQrDialogState extends State<_VoucherQrDialog> {
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
    final voucher = widget.voucher;

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
                key: const Key('voucher-qr-close'),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            Text(
              TextFormatter.fromUppercase(voucher.voucherName),
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (_isDummy(voucher)) ...[
              const SizedBox(height: 8),
              const _DummyChip(),
              const SizedBox(height: 4),
              Text(
                'Voucher contoh untuk melihat tampilan, bukan voucher asli',
                style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),

            // The payload is the raw voucher number and nothing else (no
            // prefix, no URL): whatever scans this has to expect exactly that.
            _QrFrame(
              data: voucher.voucherNo,
              semanticsLabel: 'Voucher QR code',
            ),
            const SizedBox(height: 16),
            // Selectable, so the cashier can be given the code to type when a
            // scan will not read.
            SelectableText(voucher.voucherNo, style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              _expiryNote(voucher).label,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Tunjukkan kode ini ke kasir bengkel',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
      onRefresh: () async {
        context.read<HomeBloc>().add(const HomeStatsRequested());

        // The voucher list is fetched lazily, so only refresh it once it has
        // been requested — and not while it is already loading.
        final rewards = context.read<RewardsBloc>();
        if (rewards.state is! RewardsInitial &&
            rewards.state is! RewardsLoading) {
          rewards.add(const RewardsRequested());
        }
      },
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
