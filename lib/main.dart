import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/adapters.dart';
import 'app/app_state.dart';
import 'app/screens/home_shell.dart';
import 'app/theme.dart';
import 'app/widgets/common.dart';
import 'config.dart';
import 'core/api_client.dart';
import 'core/cache.dart';
import 'core/repository.dart';
import 'core/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = PrefsStore(await SharedPreferences.getInstance());
  final api = ApiClient(
    baseUrl: AppConfig.apiBase,
    userAgent: 'AasPaasApp/${AppConfig.version} (Android)',
  );
  final cache = JsonCache(prefs);
  final repo = Repository(api, cache);
  final session = Session(
    api,
    SecureTokenStore(),
    cache,
    repo,
    deviceName: 'Android app',
  );
  final state = AppState(repo: repo, session: session, prefs: prefs);
  runApp(AasPaasApp(state: state));
  unawaited(state.init());
}

class AasPaasApp extends StatelessWidget {
  const AasPaasApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: Builder(
          builder: (context) {
            final app = AppScope.of(context);
            if (!app.ready) return const _Splash();
            return const HomeShell();
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MessageView(
        icon: Icons.storefront,
        title: AppConfig.appName,
        message: 'Loading your neighbourhood...',
      ),
    );
  }
}
