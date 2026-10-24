import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

/// deliveric.net serves an incomplete certificate chain (missing intermediate),
/// so some phones fail with "unable to get local issuer certificate".
/// Accept the certificate for this one host only.
class DelivericHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => host == 'deliveric.net';
  }
}

Future<void> main() async {
  HttpOverrides.global = DelivericHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  await Session.I.load();
  runApp(const ShipperApp());
}

class ShipperApp extends StatelessWidget {
  const ShipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (_, __) => MaterialApp(
        title: 'Shipper Deliveric',
        debugShowCheckedModeBanner: false,
        locale: Session.I.locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(Session.I.locale.languageCode == 'ar'),
        home: const SplashScreen(),
      ),
    );
  }
}
