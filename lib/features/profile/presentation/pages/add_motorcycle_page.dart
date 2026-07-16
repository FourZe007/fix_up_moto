import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/helpers/validators.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_state.dart';

/// Form for registering a new motorcycle to the user's profile.
class AddMotorcyclePage extends StatefulWidget {
  const AddMotorcyclePage({super.key});

  @override
  State<AddMotorcyclePage> createState() => _AddMotorcyclePageState();
}

class _AddMotorcyclePageState extends State<AddMotorcyclePage> {
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
      context.read<ProfileBloc>().add(
            MotorcycleAddRequested(
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
      appBar: AppBar(title: const Text('Add Motorcycle')),
      body: BlocListener<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileActionSuccess) {
            Navigator.of(context).pop();
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
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
                    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                      return 'Enter a valid year';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _plateController,
                  decoration: const InputDecoration(labelText: 'Plate Number'),
                  textCapitalization: TextCapitalization.characters,
                  validator: Validators.plateNumber,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Add Motorcycle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
