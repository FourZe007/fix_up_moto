import 'package:fix_up_moto/core/widgets/app_spinner.dart';
import 'package:fix_up_moto/core/helpers/external_link.dart';
import 'package:fix_up_moto/core/helpers/geo.dart';
import 'package:fix_up_moto/core/helpers/phone_number.dart';
import 'package:fix_up_moto/core/services/location_service.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/domain/nearest_workshop.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_bloc.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_event.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_state.dart';

/// Lets the member pick which workshop/dealer to use.
///
/// Sourced from `Master` (`Jenis: "BRANCHSHOP"`) — see [WorkshopsRemoteDataSource].
///
/// **Listed nearest first**, each card saying how far it is, closed ones at the
/// bottom (see [sortByDistance]). The page asks [LocationService] where the
/// member is and shows the list only once that is answered, so a card never
/// moves under a finger. Without a position (off, refused, too slow) the list
/// keeps the server's order, says nothing about distance, and says in a line
/// above it that the position was not found.
class WorkshopListPage extends StatelessWidget {
  const WorkshopListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WorkshopsBloc>()..add(const WorkshopsRequested()),
      child: const _WorkshopListView(),
    );
  }
}

class _WorkshopListView extends StatefulWidget {
  const _WorkshopListView();

  @override
  State<_WorkshopListView> createState() => _WorkshopListViewState();
}

class _WorkshopListViewState extends State<_WorkshopListView> {
  final _searchController = TextEditingController();
  String _query = '';

  /// How long to wait for the member's position before listing without it.
  ///
  /// A safety net, as on Create Booking: the location service limits the fix
  /// itself, but the wait also includes the member reading the system's
  /// location prompt.
  static const _locationWait = Duration(seconds: 30);

  /// Under the spinner: which of the two waits this is.
  static const _loadingText = 'Memuat...';
  static const _findingNearestText =
      'Mencari bengkel terdekat dari lokasi Anda...';

  /// Where the member is, to order the list. Null while unknown. Held only
  /// while the page is open.
  GeoPoint? _here;

  /// True until the position has been answered, with a point or without one.
  bool _locating = true;

  /// Which lookup is the latest, so an earlier one that answers late is ignored.
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final lookup = ++_lookup;
    final here = await sl<LocationService>().currentPosition().timeout(
      _locationWait,
      onTimeout: () => null,
    );
    // The page may be gone, or the list reloaded since.
    if (!mounted || lookup != _lookup) return;
    setState(() {
      _here = here;
      _locating = false;
    });
  }

  /// Pull-to-refresh and Retry: the list again, and where the member is now.
  void _reload() {
    context.read<WorkshopsBloc>().add(const WorkshopsRequested());
    setState(() => _locating = true);
    _locate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Matches on name or address — the two things someone actually remembers
  /// about a workshop, not internal fields like branch/shop codes.
  List<WorkshopEntity> _filter(List<WorkshopEntity> workshops) {
    if (_query.isEmpty) return workshops;
    final query = _query.toLowerCase();
    return workshops
        .where(
          (w) =>
              w.bsName.toLowerCase().contains(query) ||
              w.bsAddress.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brandBackdrop(context),
      appBar: AppBar(
        title: const Text('Pilih Bengkel'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // top: false — the AppBar already accounts for the status bar; this
      // guards the last workshop card from the gesture nav bar, since this
      // page has no bottomNavigationBar to reserve that space.
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          // Top-only — the bottom already meets the screen edge, so rounding
          // it wouldn't be visible against anything.
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: LightSurfaceScope(
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      // Overrides inputDecorationTheme's default fillColor
                      // (app_theme.dart) for this one field, to match the
                      // workshop cards below it.
                      filled: true,
                      fillColor: AppColors.grey200,
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Cari bengkel',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<WorkshopsBloc, WorkshopsState>(
                    builder: (context, state) {
                      return switch (state) {
                        // The list itself is still coming from the server.
                        WorkshopsInitial() ||
                        WorkshopsLoading() => const _LoadingView(_loadingText),
                        WorkshopsError(:final message) => _ErrorView(
                          message: message,
                          onRetry: _reload,
                        ),
                        // The list has arrived and only its order is waited
                        // for. (An empty one has nothing to put in order.)
                        WorkshopsLoaded(:final workshops)
                            when _locating && workshops.isNotEmpty =>
                          const _LoadingView(_findingNearestText),
                        WorkshopsLoaded(:final workshops) => _buildList(
                          context,
                          workshops,
                        ),
                      };
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<WorkshopEntity> workshops) {
    final filtered = _filter(sortByDistance(workshops, _here));

    if (workshops.isEmpty) {
      return const Center(child: Text('No workshops available'));
    }
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No workshops match "$_query"',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        // This is only built once the lookup is over, so no usable position
        // here means it failed: say why the list is not nearest first.
        if (!(_here?.isValid ?? false)) const _NoLocationNotice(),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              // Horizontal inset comes only from Card's own theme margin
              // (16px) — adding it here too would double it, leaving cards
              // narrower than the search bar above, which has 16px padding of
              // its own.
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _WorkshopCard(
                workshop: filtered[index],
                distanceKm: workshopDistanceKm(filtered[index], _here),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Above the list when the member's position could not be found (off, refused,
/// too slow): why the list is in the server's order, with no distances.
class _NoLocationNotice extends StatelessWidget {
  const _NoLocationNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // In line with the cards' own 16px inset.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.location_off_outlined, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Lokasi Anda gagal ditemukan',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// The spinner, with a line under it saying what is being waited for. One
/// widget for every wait, so the spinner keeps turning when only the line
/// changes.
class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSpinner(),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  final WorkshopEntity workshop;

  /// Straight-line distance from the member, or null if unknown.
  final double? distanceKm;
  const _WorkshopCard({required this.workshop, this.distanceKm});

  /// "± 2,4 km": approximate on purpose (a straight line from an approximate
  /// position), with the comma Bahasa uses for decimals.
  static String _distanceLabel(double km) => km < 0.1
      ? '< 0,1 km'
      : '± ${km.toStringAsFixed(1).replaceAll('.', ',')} km';

  /// Opens a WhatsApp chat with the workshop's number. WhatsApp rather than a
  /// phone call: the workshops answer on WhatsApp, and a chat leaves a record.
  void _chatOnWhatsApp(BuildContext context, String url) => openExternalLink(
    context,
    url,
    failureMessage: 'WhatsApp tidak dapat dibuka',
  );

  Future<void> _openInMaps() async {
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${workshop.lat},${workshop.lng}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Tapping the card is the pick action — no separate button needed, and it
  /// matches the pattern every other selectable list in this app already
  /// uses (a service, a booking). Returns the chosen workshop to whoever
  /// pushed this page, e.g. Home's `_WorkshopPicker`.
  void _select(BuildContext context) => context.pop(workshop);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final whatsappUrl = PhoneNumber.toWhatsAppUrl(workshop.phoneNo);

    return Card(
      // Overrides cardTheme's default color (app_theme.dart) to match the
      // search bar above it.
      color: AppColors.grey200,
      elevation: 4,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // A closed branch isn't somewhere to send a booking — the "Closed"
        // badge below is the visual cue, this is what backs it up.
        onTap: workshop.active ? () => _select(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workshop.bsName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (!workshop.active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Closed',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      workshop.bsAddress,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (distanceKm case final km?) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.near_me_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _distanceLabel(km),
                        key: Key('workshop-distance-${workshop.id}'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.schedule_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      // The backend sends literal tabs for column alignment,
                      // which don't render meaningfully in a Text widget —
                      // collapsed to a single space so lines wrap cleanly.
                      workshop.operationalHours.replaceAll(RegExp(r'\t+'), ' '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: Key('workshop-whatsapp-${workshop.id}'),
                      // Nothing to open when the backend sent no number.
                      onPressed: whatsappUrl == null
                          ? null
                          : () => _chatOnWhatsApp(context, whatsappUrl),
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openInMaps,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Maps'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
