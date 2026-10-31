import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  bool hide = true;
  String? error;

  Future<void> submit() async {
    if (user.text.trim().isEmpty || pass.text.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final r = asMap(await Api.post('/api/login', {'username': user.text.trim().toLowerCase(), 'password': pass.text}, auth: false));
      await Session.start(r['token'] as String, asMap(r['user']));
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.9), radius: 1.2, colors: [Color(0xFF2A1659), Palette.bg]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Session.setLang(isAr ? 'en' : 'ar'),
                      child: Text(isAr ? 'English' : 'العربية'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('UNDERGROUND', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3)),
                  const Text('STRENGTH & CONDITIONING', style: TextStyle(color: Palette.violetSoft, letterSpacing: 2.5, fontSize: 11)),
                  const SizedBox(height: 40),
                  UgCard(
                    padding: const EdgeInsets.all(20),
                    child: AutofillGroup(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(tr('login_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 18),
                        TextField(
                          controller: user,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: InputDecoration(labelText: tr('username'), prefixIcon: const Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: pass,
                          obscureText: hide,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: tr('password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => hide = !hide)),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(error!, style: const TextStyle(color: Palette.bad)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(tr('sign_in')),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
