import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<BikesBloc>().add(
        BikeAddRequested(
          memberId: '',
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          year: int.parse(_yearController.text.trim()),
          plateNumber: _plateController.text.trim().toUpperCase(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bike')),
      // top: false — the AppBar already accounts for the status bar; this
      // guards "Add Bike" at the form's end from the gesture nav bar, since
      // this page has no bottomNavigationBar to reserve that space.
      body: SafeArea(
        top: false,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                    validator: Validators.required('Brand'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(labelText: 'Model'),
                    validator: Validators.required('Model'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _yearController,
                    decoration: const InputDecoration(labelText: 'Year'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Year is required';
                      final year = int.tryParse(v);
                      if (year == null ||
                          year < 1900 ||
                          year > DateTime.now().year + 1) {
                        return 'Enter a valid year';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _plateController,
                    decoration: const InputDecoration(
                      labelText: 'Plate Number',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: Validators.plateNumber,
                  ),
                  const SizedBox(height: 32),
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
    );
  }
}
