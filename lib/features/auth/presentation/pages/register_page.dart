import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:fix_up_moto/core/helpers/validators.dart';

/// Registration screen — creates a new user account.
///
/// Matches [LoginPage]'s structure deliberately, down to the same four-layer
/// keyboard-safe layout: same header treatment, same field styling, same
/// "back to the other auth screen" link pattern. A returning user bouncing
/// between the two should feel like one screen, not two different apps.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      context.read<AuthBloc>().add(
        AuthRegisterRequested(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          // Left blank on the form means "no email", not "empty string".
          email: email.isEmpty ? null : email,
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar — matches LoginPage's borderless look. Getting back to
      // Login is the text link at the bottom of the form instead, the same
      // way LoginPage links forward to this screen.
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          // AuthAuthenticated is handled by AppRouter's redirect.
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            // Identical recipe to LoginPage, for identical reasons — see that
            // file for why each layer exists. On this taller form the two
            // Spacers simply compress toward zero on most screens rather than
            // visibly centering, and the form scrolls instead; nothing extra
            // is needed for that to happen correctly.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(),

                            // ── Header ───────────────────────────────────
                            Text(
                              'Join FixUp Moto',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create an account to book your service',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 40),

                            // ── Full name (required) ─────────────────────
                            AuthTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              prefixIcon: Icons.person_outlined,
                              validator: Validators.required('Full name'),
                            ),
                            const SizedBox(height: 16),

                            // ── Phone number (required) ──────────────────
                            // The identity field everywhere else in this app
                            // uses — Home's dashboard and the login form both
                            // key off it, so a manually-created account needs
                            // one too, not just Google-linked accounts.
                            AuthTextField(
                              controller: _phoneController,
                              label: 'Phone number',
                              hint: '081234567890',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: Validators.phone,
                            ),
                            const SizedBox(height: 16),

                            // ── Email (optional) ─────────────────────────
                            // Validators.optional means leaving this blank is
                            // valid, but typing something badly-formed is
                            // still rejected — "optional" isn't "unchecked".
                            AuthTextField(
                              controller: _emailController,
                              label: 'Email (optional)',
                              hint: 'you@example.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.optional(Validators.email),
                            ),
                            const SizedBox(height: 16),

                            // ── Password (required) ──────────────────────
                            AuthTextField(
                              controller: _passwordController,
                              label: 'Password',
                              prefixIcon: Icons.lock_outlined,
                              obscureText: true,
                              validator: Validators.password,
                            ),
                            const SizedBox(height: 16),

                            // ── Confirm password (required) ──────────────
                            AuthTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              prefixIcon: Icons.lock_outlined,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: Validators.confirmPassword(
                                _passwordController.text,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── Create account button ────────────────────
                            ElevatedButton(
                              onPressed: isLoading ? null : _onRegisterPressed,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Create Account'),
                            ),

                            // ── Back to login ────────────────────────────
                            // Mirrors LoginPage's own "Tidak punya akun?
                            // Daftar disini" link, just pointed the other way.
                            // pop(), not go(RouteNames.login): Register was
                            // reached by pushing on top of Login, which is
                            // still on the stack underneath — go() would push
                            // a second, redundant Login route instead of
                            // returning to the one already there.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Sudah punya akun?'),
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.pop(),
                                  child: const Text(
                                    'Masuk disini',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
