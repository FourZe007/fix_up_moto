import 'dart:convert';
import 'dart:typed_data';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/validators.dart';
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
  // Shared with _PhotoPicker's own `diameter` param, so the avatar's size
  // only ever needs to change in this one place.
  static const double _photoDiameter = 100;

  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
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

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
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
          memberId: '',
          plateNumber: _plateController.text.trim().toUpperCase(),
          unitId:
              '${_brandController.text.trim()} ${_modelController.text.trim()}',
          chasisNo: _chasisController.text.trim(),
          engineNo: _engineController.text.trim(),
          color: _colorController.text.trim(),
          year: int.parse(_yearController.text.trim()),
          photo: _photoBytes == null ? '' : base64Encode(_photoBytes!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        // This route is only ever reached from MyBikesPage's own FAB, so
        // go()-ing there directly (rather than a plain pop) guarantees a
        // fresh BikesBloc/reload instead of resuming whatever state the
        // previous instance was left in.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.myBikes),
        ),
      ),
      // top: false — the AppBar above already accounts for the status bar;
      // this guards "Add Bike" at the form's end from the gesture nav bar,
      // since this page has no bottomNavigationBar to reserve that space.
      body: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppColors.primary),
          child: Column(
            children: [
              // Same orange as the AppBar above it, so the two read as one
              // continuous banner with the photo avatar centered inside it —
              // no seam, and no manual overlay/positioning math needed.
              Expanded(
                child: _PhotoPicker(
                  diameter: _photoDiameter,
                  photoBytes: _photoBytes,
                  onPick: _pickPhoto,
                  onRemove: _removePhoto,
                ),
              ),

              Expanded(
                flex: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    // Top-only — the bottom already meets the screen edge, so
                    // rounding it wouldn't be visible against anything.
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(50),
                    ),
                  ),
                  child: BlocListener<BikesBloc, BikesState>(
                    listener: (context, state) {
                      if (state is BikeActionSuccess) {
                        Navigator.of(context).pop();
                      } else if (state is BikesError) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(state.message)));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                      child: Column(
                        spacing: 32,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  spacing: 16,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _brandController,
                                      decoration: const InputDecoration(
                                        labelText: 'Brand',
                                      ),
                                      validator: Validators.required('Brand'),
                                    ),
                                    TextFormField(
                                      controller: _modelController,
                                      decoration: const InputDecoration(
                                        labelText: 'Model',
                                      ),
                                      validator: Validators.required('Model'),
                                    ),
                                    TextFormField(
                                      controller: _colorController,
                                      decoration: const InputDecoration(
                                        labelText: 'Color',
                                      ),
                                      validator: Validators.required('Color'),
                                    ),
                                    TextFormField(
                                      controller: _yearController,
                                      decoration: const InputDecoration(
                                        labelText: 'Year',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Year is required';
                                        }
                                        final year = int.tryParse(v);
                                        if (year == null ||
                                            year < 1900 ||
                                            year > DateTime.now().year + 1) {
                                          return 'Enter a valid year';
                                        }
                                        return null;
                                      },
                                    ),
                                    TextFormField(
                                      controller: _plateController,
                                      decoration: const InputDecoration(
                                        labelText: 'Plate Number',
                                      ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      validator: Validators.plateNumber,
                                    ),
                                    TextFormField(
                                      controller: _chasisController,
                                      decoration: const InputDecoration(
                                        labelText: 'Chasis Number',
                                      ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      validator: Validators.required(
                                        'Chasis Number',
                                      ),
                                    ),
                                    TextFormField(
                                      controller: _engineController,
                                      decoration: const InputDecoration(
                                        labelText: 'Engine Number',
                                      ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      validator: Validators.required(
                                        'Engine Number',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _submit,
                            child: const Text('Add Bike'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable circular photo avatar — gallery-only selection (no camera
/// capture option) — centered in the orange banner above the form (see
/// _AddBikeViewState.build), with a grey-backed circle and icon fallback
/// while empty. A small close badge overlays the corner once a photo is
/// picked, to clear it without needing to open the gallery again just to
/// pick a replacement.
class _PhotoPicker extends StatelessWidget {
  final double diameter;
  final Uint8List? photoBytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoPicker({
    required this.diameter,
    required this.photoBytes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = photoBytes;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onPick,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Container(
                  width: diameter,
                  height: diameter,
                  color: AppColors.grey200,
                  alignment: Alignment.center,
                  child: bytes == null
                      ? const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.grey600,
                          size: 32,
                        )
                      : Image.memory(
                          bytes,
                          width: diameter,
                          height: diameter,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              if (bytes != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(12),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bytes == null ? 'Add Photo' : 'Change Photo',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
