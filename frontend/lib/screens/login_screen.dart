import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'driver/profile_completion_screen.dart';
import 'otp_verification_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  static const _demoCredentials = [
    ('Admin', 'admin@example.com', 'Demo@1234'),
    ('Fleet Manager', 'manager@example.com', 'Demo@1234'),
    ('Driver', 'driver@example.com', 'Demo@1234'),
  ];

  void _autofill(String email, String password) {
    _emailCtrl.text = email;
    _passwordCtrl.text = password;
  }

  Future<void> _signIn() async {
    if (_loading) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('Please enter email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().signIn(email, password);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } on OtpRequiredException catch (e) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              transientToken: e.transientToken,
              email: email,
            ),
          ),
        );
      }
    } on ProfileIncompleteException {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppConstants.severityCritical : null,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.primaryOrange,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
              flex: 4,
              child: _TopSection(),
            ),
            Expanded(
              flex: 6,
              child: _BottomCard(
                emailCtrl: _emailCtrl,
                passwordCtrl: _passwordCtrl,
                obscure: _obscure,
                loading: _loading,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                onSignIn: _signIn,
                onAutofill: _autofill,
                demoCredentials: _demoCredentials,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Text(
              'NPD Fuel Management',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppConstants.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Fuel Monitoring & Management',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppConstants.white.withValues(alpha: 0.85),
              ),
            ),
            Text(
              'Reliability is our strength',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppConstants.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool loading;
  final VoidCallback onToggleObscure;
  final VoidCallback onSignIn;
  final Function(String, String) onAutofill;
  final List<(String, String, String)> demoCredentials;

  const _BottomCard({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.loading,
    required this.onToggleObscure,
    required this.onSignIn,
    required this.onAutofill,
    required this.demoCredentials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppConstants.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sign In',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.darkText)),
            const SizedBox(height: 2),
            Text('Enter your credentials to continue',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppConstants.mediumText)),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'your@email.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loading ? null : onSignIn,
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Sign In'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              ),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('New Driver? Sign Up'),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppConstants.lightOrangeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.primaryOrange),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline,
                        color: AppConstants.primaryOrange, size: 16),
                    const SizedBox(width: 6),
                    Text('Demo Credentials',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryOrange)),
                  ]),
                  const SizedBox(height: 8),
                  ...demoCredentials.map((c) => _DemoRow(
                        role: c.$1,
                        email: c.$2,
                        password: c.$3,
                        onTap: () => onAutofill(c.$2, c.$3),
                      )),
                  const SizedBox(height: 4),
                  Text('Tap row to auto-fill',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: AppConstants.mediumText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoRow extends StatelessWidget {
  final String role;
  final String email;
  final String password;
  final VoidCallback onTap;

  const _DemoRow(
      {required this.role,
      required this.email,
      required this.password,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 60,
            child: Text(role,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.darkText)),
          ),
          Expanded(
            child: Text('$email / $password',
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppConstants.mediumText)),
          ),
          const Icon(Icons.touch_app_outlined,
              size: 13, color: AppConstants.primaryOrange),
        ]),
      ),
    );
  }
}
