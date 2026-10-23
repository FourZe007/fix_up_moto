import 'dart:convert';
import 'dart:typed_data';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/warm_section.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';

/// Form for registering a new bike to the user's profile.
///
/// Reached via `context.push(RouteNames.addBike)` — a top-level route, so
/// (like CreateBookingPage before it) this needs its own [BikesBloc] rather
/// than assuming an ancestor provides one, which a pushed page can never see.
class AddBikePage extends StatelessWidget {
  const AddBikePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BikesBloc>(),
      child: const _AddBikeView(),
    );
  }
}

class _AddBikeView extends StatefulWidget {
  const _AddBikeView();

  @override
  State<_AddBikeView> createState() => _AddBikeViewState();
}

class _AddBikeViewState extends State<_AddBikeView> {
  final _formKey = GlobalKey<FormState>();
  // Feeds BikeAddRequested.unitId directly — the backend has no separate
  // brand/model fields (BikeEntity only ever stores one combined string,
  // e.g. "YAMAHA R25"), so this is one field rather than two that just get
  // concatenated before submit.
  final _unitIdController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _chasisController = TextEditingController();
  final _engineController = TextEditingController();
  Uint8List? _photoBytes;

  Future<void> _pickPhoto() async {
    // Gallery only — the user isn't offered a camera capture option here.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _photoBytes = bytes);
  }

  void _removePhoto() => setState(() => _photoBytes = null);

  /// Local, Bahasa-language required-field check — kept on this page rather
  /// than in the shared `Validators` helper, since that class's messages are
  /// English and reused by Login/Register/other forms this page shouldn't
  /// change the wording of.
  String? _required(String fieldName, String? value) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  /// Same alphanumeric 3-8 character check as the shared
  /// `Validators.plateNumber`, just with Bahasa messages for this page.
  String? _plateNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Plat nomor wajib diisi';
    }
    final cleaned = value.trim().replaceAll(' ', '');
    if (!RegExp(r'^[A-Z0-9]{3,8}$', caseSensitive: false).hasMatch(cleaned)) {
      return 'Masukkan plat nomor yang valid (contoh: L 1234 AB)';
    }
    return null;
  }

  @override
  void dispose() {
    _unitIdController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _chasisController.dispose();
    _engineController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<BikesBloc>().add(
        BikeAddRequested(
          plateNumber: _plateController.text.trim().toUpperCase(),
          unitId: _unitIdController.text.trim(),
          chasisNo: _chasisController.text.trim(),
          engineNo: _engineController.text.trim(),
          color: _colorController.text.trim(),
          year: _yearController.text.trim(),
          photo: _photoBytes == null ? '' : base64Encode(_photoBytes!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The colour comes from the active Theme rather than an AppColors
    // constant, so this bar follows light/dark automatically. The title and
    // arrow are coloured explicitly because the app's AppBarTheme hard-codes a
    // white title style.
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // The same warm wash as Profile: a fixed backdrop *around* the Scaffold,
    // whose own background and AppBar are transparent, so it shows behind the
    // bar and the form scrolls over it.
    return WarmWash(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Tambah Motor',
            style: TextStyle(color: onSurface, fontSize: 20),
          ),
          // Plain pop, not go(RouteNames.myBikes) — this route is pushed from
          // two different places (MyBikesPage's FAB and ProfilePage's own "+"
          // shortcut), and go() unconditionally to one of them would both
          // land the wrong caller on the wrong page and wipe out the rest of
          // the navigation stack (go() replaces the whole stack with just the
          // target route, since these are top-level routes outside any
          // ShellRoute — that's what was making the AppBar's own back button
          // disappear from MyBikesPage afterwards).
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(foregroundColor: onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        // top: false — the AppBar above already accounts for the status bar;
        // this guards "Tambah Motor" at the form's end from the gesture nav
        // bar, since this page has no bottomNavigationBar to reserve that
        // space.
        body: SafeArea(
          top: false,
          child: BlocListener<BikesBloc, BikesState>(
            listener: (context, state) {
              if (state is BikesAdded) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Motor berhasil ditambah!')),
                );

                // A new bike can change the member's stats (Home, Membership
                // and Profile are alive in the tab stack), so tell them to
                // reload. Read before the pop, while this context is active.
                context.read<DataRefreshCubit>().invalidate(DataKind.stats);

                // Popping with `true` lets whichever caller pushed this
                // route (MyBikesPage's FAB) know a bike was actually added,
                // so it can refresh its own (separate) BikesBloc instance —
                // this page's Bloc and the caller's are different
                // page-scoped instances, so a plain pop alone wouldn't
                // surface the new bike there.
                context.pop(true);
              } else if (state is BikesError) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                spacing: 24,
                children: [
                  // Input Textfields
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        // Surfaces each field's error as soon as the user
                        // leaves it, rather than dumping every error at
                        // once on submit.
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          spacing: 16,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader('Informasi Motor'),
                            AuthTextField(
                              controller: _unitIdController,
                              label: 'Merek & Model',
                              hint: 'Contoh: Honda Supra x 125',
                              prefixIcon: Icons.two_wheeler_outlined,
                              validator: (v) => _required('Merek & Model', v),
                            ),
                            AuthTextField(
                              controller: _colorController,
                              label: 'Warna',
                              hint: 'Contoh: Hitam',
                              prefixIcon: Icons.palette_outlined,
                              // validator: (v) => _required('Warna', v),
                            ),
                            AuthTextField(
                              controller: _yearController,
                              label: 'Tahun',
                              hint: 'Contoh: 2023',
                              prefixIcon: Icons.calendar_today_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                // if (v == null || v.isEmpty) {
                                //   return 'Tahun wajib diisi';
                                // }
                                if (v != null && v.isNotEmpty) {
                                  final year = int.tryParse(v);
                                  if (year == null ||
                                      year < 1900 ||
                                      year > DateTime.now().year + 1) {
                                    return 'Masukkan tahun yang valid';
                                  }
                                }
                                return null;
                              },
                            ),
                            const Divider(
                              height: 20,
                              color: AppColors.peachHairline,
                            ),
                            const SectionHeader('Registrasi'),
                            AuthTextField(
                              controller: _plateController,
                              label: 'Plat Nomor',
                              hint: 'Contoh: L 1234 AB',
                              prefixIcon: Icons.confirmation_number_outlined,
                              textCapitalization: TextCapitalization.characters,
                              validator: _plateNumberValidator,
                            ),
                            AuthTextField(
                              controller: _chasisController,
                              label: 'No Chasis',
                              hint: 'Masukkan nomor rangka',
                              prefixIcon: Icons.tag,
                              textCapitalization: TextCapitalization.characters,
                              // validator: (v) => _required('No Chasis', v),
                            ),
                            AuthTextField(
                              controller: _engineController,
                              label: 'No Mesin',
                              hint: 'Masukkan nomor mesin',
                              prefixIcon: Icons.settings_outlined,
                              textCapitalization: TextCapitalization.characters,
                              // The last field: the keyboard's action closes it
                              // rather than jumping on.
                              textInputAction: TextInputAction.done,
                              // validator: (v) => _required('No Mesin', v),
                            ),
                            const Divider(
                              height: 20,
                              color: AppColors.peachHairline,
                            ),
                            const SectionHeader('Foto'),
                            _PhotoPicker(
                              photoBytes: _photoBytes,
                              onPick: _pickPhoto,
                              onRemove: _removePhoto,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Add Button
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Tambah Motor'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable photo box — gallery-only selection (no camera capture option) —
/// a wide dashed-border rectangle (the common "empty upload/drop target"
/// convention) so it reads as an optional attachment field, not a
/// highlighted hero element. Empty, it opens the gallery on tap; once a
/// photo is picked, tapping the box instead opens a full-screen preview,
/// and the only way to change it is the small close badge, which clears it
/// back to the empty state.
class _PhotoPicker extends StatelessWidget {
  // 64 (thumbnail) + 8px inset on top and bottom (matching the Padding(8.0)
  // wrapping the box's content) — close to the thumbnail's own size instead
  // of leaving a wide empty margin above and below it.
  static const double _boxHeight = 80;
  // Same 64x64 scale as MyBikesPage's own bike photo thumbnail, so a picked
  // photo previews at a consistent, modest size instead of blowing up to
  // fill the whole dashed box.
  static const double _thumbnailSize = 64;

  final Uint8List? photoBytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoPicker({
    required this.photoBytes,
    required this.onPick,
    required this.onRemove,
  });

  void _showFullScreen(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.memory(bytes)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = photoBytes;

    return GestureDetector(
      onTap: bytes == null ? onPick : () => _showFullScreen(context, bytes),
      child: Stack(
        children: [
          // Same dashed box in both states — filled or empty — so a picked
          // photo doesn't suddenly grow into a full-bleed banner; only what
          // sits centered inside it changes.
          // Container(decoration: dotted),
          CustomPaint(
            // The brand orange on the palest peach: 3.8:1 against the page and
            // more than 3:1 against its own fill, enough for a graphic.
            painter: const _DashedBorderPainter(
              color: AppColors.primary,
              fillColor: AppColors.peachMist,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: double.infinity,
                height: _boxHeight,
                child: Align(
                  // Icon stays centered while empty; once a photo is picked,
                  // its thumbnail sits center-left instead of dead-center.
                  alignment: bytes == null
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: bytes == null
                      ? const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primary,
                          size: 32,
                        )
                      // A local Stack scoped to just the thumbnail's own
                      // bounds, so the close badge tracks the image's actual
                      // top-right corner wherever it sits in the outer box,
                      // rather than the box's own corner.
                      : SizedBox(
                          width: _thumbnailSize,
                          height: _thumbnailSize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    bytes,
                                    width: _thumbnailSize,
                                    height: _thumbnailSize,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -10,
                                right: -10,
                                child: InkWell(
                                  onTap: onRemove,
                                  borderRadius: BorderRadius.circular(12),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.black54,
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border — the standard visual cue for
/// an empty upload/drop target, distinguishing it from a solid-bordered box
/// that could be mistaken for already-filled content — over a soft [fillColor].
class _DashedBorderPainter extends CustomPainter {
  // Matches the box's own ClipRRect radius so the dashes trace exactly
  // along its rounded corners.
  static const double _radius = 12;
  static const double _dashLength = 6;
  static const double _gapLength = 4;

  final Color color;
  final Color fillColor;

  const _DashedBorderPainter({required this.color, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(_radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fillColor);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color || fillColor != oldDelegate.fillColor;
  }
}
