import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/confirm_panel_scope.dart';
import 'package:fix_up_moto/core/widgets/warm_section.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/widgets/bike_photo_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// What the member entered, trimmed and ready to send. [photo] is already the
/// string to send: base64 of a newly picked image, `''` when the photo was
/// removed (or never chosen), or the bike's original photo string untouched.
class BikeFormValues {
  final String plateNo;
  final String unitId;
  final String chasisNo;
  final String engineNo;
  final String color;
  final String year;
  final String photo;

  const BikeFormValues({
    required this.plateNo,
    required this.unitId,
    required this.chasisNo,
    required this.engineNo,
    required this.color,
    required this.year,
    required this.photo,
  });
}

/// The bike details form, shared by Add Bike and Edit Bike: the same fields,
/// validation, photo box and submit button, so the two cannot drift apart.
///
/// Add Bike passes nothing but a [submitLabel]; Edit Bike passes the bike it is
/// editing as [initial] to prefill every field. Every field, the plate
/// included, is editable: which bike an edit means is carried by the record's
/// own `Line`, which the page sends and the form never touches.
///
/// Removing the photo asks first, so the page must sit under a
/// [ConfirmPanelScope].
class BikeForm extends StatefulWidget {
  /// The bike being edited, or null for a new one.
  final BikeEntity? initial;

  final String submitLabel;

  /// Disables the submit button while a save is in flight, so a second tap
  /// cannot send it twice.
  final bool isLoading;

  /// Called with the entered values once the form validates.
  final ValueChanged<BikeFormValues> onSubmit;

  const BikeForm({
    super.key,
    this.initial,
    this.isLoading = false,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<BikeForm> createState() => _BikeFormState();
}

class _BikeFormState extends State<BikeForm> {
  final _formKey = GlobalKey<FormState>();
  // Feeds BikeFormValues.unitId directly — the backend has no separate
  // brand/model fields (BikeEntity only ever stores one combined string,
  // e.g. "YAMAHA R25"), so this is one field rather than two that just get
  // concatenated before submit.
  late final _unitIdController = TextEditingController(
    text: widget.initial?.unitId,
  );
  late final _colorController = TextEditingController(
    text: widget.initial?.color,
  );
  late final _yearController = TextEditingController(
    text: widget.initial?.year,
  );
  late final _plateController = TextEditingController(
    text: widget.initial?.plateNo,
  );
  late final _chasisController = TextEditingController(
    text: widget.initial?.chasisNo,
  );
  late final _engineController = TextEditingController(
    text: widget.initial?.engineNo,
  );

  /// A photo picked in this form; wins over the bike's stored one.
  Uint8List? _pickedBytes;

  /// The member cleared the photo — also hides the bike's stored one.
  bool _photoRemoved = false;

  /// The bike's stored photo, decoded once rather than on every rebuild (a
  /// base64 photo can be large).
  late final ImageProvider? _storedImage = bikePhotoProvider(
    widget.initial?.photo ?? '',
  );

  ImageProvider? get _photoImage {
    final picked = _pickedBytes;
    if (picked != null) return MemoryImage(picked);
    return _photoRemoved ? null : _storedImage;
  }

  /// Three outcomes — replaced: the new image as base64; removed: `''`;
  /// untouched: the stored string exactly as it came, never re-encoded.
  ///
  /// UNVERIFIED for an untouched stored URL: sending it back as `Photo`
  /// assumes the backend keeps it, which can't be checked until real photo data
  /// exists (every response seen so far had an empty photo).
  String get _photoValue {
    final picked = _pickedBytes;
    if (picked != null) return base64Encode(picked);
    if (_photoRemoved) return '';
    return widget.initial?.photo ?? '';
  }

  Future<void> _pickPhoto() async {
    // Gallery only — the user isn't offered a camera capture option here.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) {
      setState(() {
        _pickedBytes = bytes;
        _photoRemoved = false;
      });
    }
  }

  /// Asks first, in the sliding confirmation panel — the page hosts a
  /// [ConfirmPanelScope] for it. Declining, or leaving the panel any other way,
  /// keeps the photo.
  Future<void> _removePhoto() async {
    // The panel slides up in the root Overlay, which a raised keyboard would
    // cover; a tap on the close badge doesn't take focus from a field.
    FocusManager.instance.primaryFocus?.unfocus();

    final confirmed = await ConfirmPanelScope.of(context).confirm(
      icon: Icons.delete,
      title: 'Hapus Foto',
      message: 'Yakin ingin menghapus foto motor ini?',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _pickedBytes = null;
      _photoRemoved = true;
    });
  }

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
      log('onSubmit Edit Bike');
      log('plateNo: ${_plateController.text.toString()}');
      log('unitId: ${_unitIdController.text.toString()}');
      log('chasisNo: ${_chasisController.text.toString()}');
      log('engineNo: ${_engineController.text.toString()}');
      log('color: ${_colorController.text.toString()}');
      log('year: ${_yearController.text.toString()}');
      log('Photo: $_photoValue');

      widget.onSubmit(
        BikeFormValues(
          plateNo: _plateController.text.trim().toUpperCase(),
          unitId: _unitIdController.text.trim(),
          chasisNo: _chasisController.text.trim(),
          engineNo: _engineController.text.trim(),
          color: _colorController.text.trim(),
          year: _yearController.text.trim(),
          photo: _photoValue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    ),
                    AuthTextField(
                      controller: _yearController,
                      label: 'Tahun',
                      hint: 'Contoh: 2023',
                      prefixIcon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) {
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
                    const Divider(height: 20, color: AppColors.peachHairline),
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
                    ),
                    const Divider(height: 20, color: AppColors.peachHairline),
                    const SectionHeader('Foto'),
                    _PhotoPicker(
                      image: _photoImage,
                      onPick: _pickPhoto,
                      onRemove: _removePhoto,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Submit Button
          ElevatedButton(
            onPressed: widget.isLoading ? null : _submit,
            child: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

/// Tappable photo box — gallery-only selection (no camera capture option) —
/// a wide dashed-border rectangle (the common "empty upload/drop target"
/// convention) so it reads as an optional attachment field, not a
/// highlighted hero element. Empty, it opens the gallery on tap; once a
/// photo is picked (or the bike already has one), tapping the box instead
/// opens a full-screen preview, and the only way to change it is the small
/// close badge, which clears it back to the empty state.
class _PhotoPicker extends StatelessWidget {
  // 64 (thumbnail) + 8px inset on top and bottom (matching the Padding(8.0)
  // wrapping the box's content) — close to the thumbnail's own size instead
  // of leaving a wide empty margin above and below it.
  static const double _boxHeight = 80;
  // Same 64x64 scale as MyBikesPage's own bike photo thumbnail, so a picked
  // photo previews at a consistent, modest size instead of blowing up to
  // fill the whole dashed box.
  static const double _thumbnailSize = 64;

  final ImageProvider? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoPicker({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  void _showFullScreen(BuildContext context, ImageProvider image) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image(
                image: image,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Gagal memuat foto.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
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
    final photo = image;

    return GestureDetector(
      onTap: photo == null ? onPick : () => _showFullScreen(context, photo),
      child: Stack(
        children: [
          // Same dashed box in both states — filled or empty — so a picked
          // photo doesn't suddenly grow into a full-bleed banner; only what
          // sits centered inside it changes.
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
                  alignment: photo == null
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: photo == null
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
                                  child: Image(
                                    image: photo,
                                    width: _thumbnailSize,
                                    height: _thumbnailSize,
                                    fit: BoxFit.cover,
                                    // A stored photo may be a URL that no
                                    // longer loads; show the empty-photo icon
                                    // rather than a broken-image box.
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.two_wheeler_outlined,
                                      color: AppColors.primary,
                                    ),
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
