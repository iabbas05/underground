import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'core/update.dart';
import 'screens/admin_shell.dart';
import 'screens/login.dart';
import 'screens/staff_shell.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorWidget.builder = (d) => Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: const Color(0xFF0A090E),
            child: Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Text('ERROR: ${d.exceptionAsString()}', style: const TextStyle(color: Colors.redAccent)))),
          ),
        );
    try {
      await Session.load();
    } catch (_) {
      // Offline or server unreachable: still open the app (login screen).
    }
    runApp(const UgApp());
  }, (e, st) {
    // Never close the app silently.
  });
}

class UgApp extends StatelessWidget {
  const UgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (context, lang, _) => MaterialApp(
        title: 'UNDERGROUND',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: Locale(lang),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ValueListenableBuilder<bool>(
          valueListenable: Session.signedIn,
          builder: (context, signedIn, _) {
            if (!signedIn) return const LoginScreen();
            return UpdateGate(child: Session.isAdmin ? const AdminShell() : const StaffShell());
          },
        ),
      ),
    );
  }
}
