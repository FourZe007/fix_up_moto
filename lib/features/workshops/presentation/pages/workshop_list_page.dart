import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_bloc.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_event.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_state.dart';

/// Lets the member pick which workshop/dealer to use.
///
/// Sourced from `Master` (`Jenis: "BRANCHSHOP"`) — see [WorkshopsRemoteDataSource].
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
      appBar: AppBar(title: const Text('Select Workshop')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by workshop name or address',
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
                  WorkshopsInitial() || WorkshopsLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  WorkshopsError(:final message) => _ErrorView(
                    message: message,
                    onRetry: () => context.read<WorkshopsBloc>().add(
                      const WorkshopsRequested(),
                    ),
                  ),
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
    );
  }

  Widget _buildList(BuildContext context, List<WorkshopEntity> workshops) {
    final filtered = _filter(workshops);

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

    return RefreshIndicator(
      onRefresh: () async =>
          context.read<WorkshopsBloc>().add(const WorkshopsRequested()),
      child: ListView.builder(
        // Horizontal inset comes only from Card's own theme margin (16px) —
        // adding it here too would double it, leaving cards narrower than
        // the search bar above, which has 16px padding of its own.
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) =>
            _WorkshopCard(workshop: filtered[index]),
      ),
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  final WorkshopEntity workshop;
  const _WorkshopCard({required this.workshop});

  Future<void> _call() async {
    final digits = workshop.phoneNo.replaceAll(RegExp(r'[^0-9+]'), '');
    await launchUrl(Uri.parse('tel:$digits'));
  }

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

    return Card(
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
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 12),
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
