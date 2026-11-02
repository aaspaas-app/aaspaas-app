import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../app_state.dart';
import '../launch.dart';

/// Opens the sign-in screen when the person is not signed in. Returns true when they are signed in afterwards.
Future<bool> requireLogin(BuildContext context) async {
  final app = AppScope.of(context);
  if (app.loggedIn) return true;
  await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const AuthScreen()));
  return app.loggedIn;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startWithRegister = false});
  final bool startWithRegister;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  late bool _register = widget.startWithRegister;
  String _type = 'customer';
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;
  String? _info;
  bool _canResend = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final app = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
      _canResend = false;
    });
    try {
      if (_register) {
        final msg = await app.register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          type: _type,
          phone: _phone.text,
        );
        if (!mounted) return;
        setState(() {
          _register = false;
          _info = msg;
          _canResend = true;
          _password.clear();
        });
      } else {
        await app.login(_email.text, _password.text);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _canResend = e.code == 'unverified';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final app = AppScope.of(context);
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Type your email above first.');
      return;
    }
    try {
      final msg = await app.resend(_email.text);
      if (mounted) toast(context, msg);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Create account' : 'Log in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('Log in')),
                ButtonSegment<bool>(value: true, label: Text('Sign up')),
              ],
              selected: {_register},
              onSelectionChanged: (s) => setState(() {
                _register = s.first;
                _error = null;
                _info = null;
              }),
            ),
            const SizedBox(height: 20),
            if (_info != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _info!,
                  style: const TextStyle(color: Color(0xFF166534)),
                ),
              ),
            Form(
              key: _form,
              child: Column(
                children: [
                  if (_register) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Your name'),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      return (s.contains('@') && s.contains('.'))
                          ? null
                          : 'Please enter a valid email';
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    textInputAction: _register
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_register) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: _register
                          ? 'Password (8 or more characters)'
                          : 'Password',
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    validator: (v) {
                      final s = v ?? '';
                      if (s.isEmpty) return 'Please enter your password';
                      if (_register && s.length < 8)
                        return 'Use at least 8 characters';
                      return null;
                    },
                  ),
                  if (_register) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'customer',
                          label: Text("I'm a customer"),
                        ),
                        ButtonSegment<String>(
                          value: 'business',
                          label: Text('I own a business'),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) =>
                          setState(() => _type = s.first),
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_register ? 'Create account' : 'Log in'),
            ),
            if (_canResend)
              TextButton(
                onPressed: _resend,
                child: const Text('Send the verification email again'),
              ),
            if (_register)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'We will email you a link. Open it once to confirm your address, then log in.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
