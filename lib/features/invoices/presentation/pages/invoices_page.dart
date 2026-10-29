import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/constants/translation_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_event.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_state.dart';
import 'package:fix_up_moto/features/invoices/presentation/widgets/invoice_card.dart';

/// The member's invoices: **Servis** and **Sparepart** as two tabs, each its
/// own list, in the same warm look as the Profile page.
///
/// The two kinds are the same request with a different `Kode`, but each tab
/// owns its [InvoicesBloc], so one can load, fail or be refreshed without
/// touching the other. A tab loads when it is first shown and then stays alive.
/// The date range under the tabs opens on the last twelve months, and changing
/// it reloads both tabs. Every card has an "Unduh Struk" button, shown but not
/// pressable until receipt download exists.
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage>
    with SingleTickerProviderStateMixin {
  /// The tabs, left to right.
  static const _types = [InvoiceType.service, InvoiceType.sparepart];

  /// The earliest day the range can reach back to.
  static final _firstSelectableDay = DateTime(2020);

  late final TabController _tabController = TabController(
    length: _types.length,
    vsync: this,
  );

  late DateTimeRange _range = _lastTwelveMonths();

  /// Today and the same day a year ago, at midnight.
  static DateTimeRange _lastTwelveMonths() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(
      start: DateTime(today.year - 1, today.month, today.day),
      end: today,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _firstSelectableDay,
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'Pilih rentang tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      saveText: 'Pilih',
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    // The page is light in dark mode too, so all of it — app bar included — is
    // built from the light theme there. The wash is a fixed backdrop *around* a
    // Scaffold whose own background and app bar are transparent (as on Profile
    // and Kotak Masuk), so it shows behind the bar and the cards scroll over it.
    return LightSurfaceScope(
      child: WarmWash(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            backgroundColor: Colors.transparent,
            title: const Text('Riwayat Invoice'),
            titleTextStyle: TextStyle(
              color: AppColors.backgroundBlack,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(
                foregroundColor: AppColors.backgroundBlack,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              // The app's TabBarTheme is white, for the orange app bar; this
              // bar is clear, so the colours are set here.
              labelColor: AppColors.primaryDark,
              unselectedLabelColor: AppColors.grey700,
              indicatorColor: AppColors.primary,
              dividerColor: AppColors.peachHairline,
              tabs: const [
                Tab(text: 'Servis'),
                Tab(text: 'Sparepart'),
              ],
            ),
          ),
          body: Column(
            children: [
              _RangeChip(range: _range, onTap: _pickRange),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final type in _types)
                      _InvoiceTab(
                        key: ValueKey(type),
                        type: type,
                        range: _range,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The days the lists cover, as a chip that opens the range picker.
class _RangeChip extends StatelessWidget {
  final DateTimeRange range;
  final VoidCallback onTap;

  const _RangeChip({required this.range, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          key: const Key('invoices-range-chip'),
          avatar: const Icon(
            Icons.date_range_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          label: Text(
            '${DateTimeFormatter.toShortDateId(range.start)} - '
            '${DateTimeFormatter.toShortDateId(range.end)}',
          ),
          backgroundColor: AppColors.peachMist,
          side: const BorderSide(color: AppColors.peachHairline),
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// One tab: owns the bloc for its [type], loads it, and reloads when [range]
/// changes. Kept alive so switching tabs does not ask the server again.
class _InvoiceTab extends StatefulWidget {
  final InvoiceType type;
  final DateTimeRange range;

  const _InvoiceTab({super.key, required this.type, required this.range});

  @override
  State<_InvoiceTab> createState() => _InvoiceTabState();
}

class _InvoiceTabState extends State<_InvoiceTab>
    with AutomaticKeepAliveClientMixin {
  late final InvoicesBloc _bloc = sl<InvoicesBloc>();

  @override
  bool get wantKeepAlive => true;

  /// The request for this tab's kind over the current range.
  InvoicesRequested get _request => InvoicesRequested(
    type: widget.type,
    beginDate: widget.range.start,
    endDate: widget.range.end,
  );

  @override
  void initState() {
    super.initState();
    _bloc.add(_request);
  }

  @override
  void didUpdateWidget(_InvoiceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range) _bloc.add(_request);
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  /// Reloads and resolves once the answer is in, so the pull indicator keeps
  /// spinning for exactly that long.
  Future<void> _refresh() {
    _bloc.add(_request);

    return _bloc.stream
        .firstWhere(
          (state) => state is InvoicesLoaded || state is InvoicesError,
          // The page closed meanwhile: nothing left to wait for.
          orElse: () => const InvoicesInitial(),
        )
        .then<void>((_) {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return BlocBuilder<InvoicesBloc, InvoicesState>(
      bloc: _bloc,
      // A reload keeps the list on screen under the pull indicator instead of
      // swapping it for a spinner; only the answer changes it.
      buildWhen: (previous, current) =>
          !(previous is InvoicesLoaded && current is InvoicesLoading),
      builder: (context, state) => switch (state) {
        InvoicesInitial() ||
        InvoicesLoading() => const Center(child: CircularProgressIndicator()),
        InvoicesError(:final message) => _ErrorView(
          type: widget.type,
          message: message,
          onRetry: () => _bloc.add(_request),
        ),
        InvoicesLoaded(:final invoices) => RefreshIndicator(
          onRefresh: _refresh,
          child: invoices.isEmpty
              ? _EmptyView(type: widget.type)
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: invoices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      InvoiceCard(invoice: invoices[index]),
                ),
        ),
      },
    );
  }
}

/// The word for a kind in a sentence: "servis" or "sparepart".
String _kindWord(InvoiceType type) =>
    type == InvoiceType.service ? 'servis' : 'sparepart';

class _StateIcon extends StatelessWidget {
  final IconData icon;

  const _StateIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.peachMist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 32, color: AppColors.primary),
    );
  }
}

/// Nothing in the range. Scrollable, so pulling down still reloads it.
class _EmptyView extends StatelessWidget {
  final InvoiceType type;

  const _EmptyView({required this.type});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  const _StateIcon(Icons.receipt_long_outlined),
                  Text(
                    'Belum ada invoice ${_kindWord(type)}',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Pada rentang tanggal ini.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.grey700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final InvoiceType type;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.type,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const _StateIcon(Icons.error_outline),
            // The failure messages are English; show them in Indonesian when
            // there is a translation for them.
            Text(
              TranslationConstants.translate(message),
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              key: ValueKey('invoices-retry-${type.wireValue}'),
              onPressed: onRetry,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
