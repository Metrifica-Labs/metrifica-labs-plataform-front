import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/supabase/supabase_client.dart' as config;
import 'core/theme/app_theme.dart';

const _envUrl = String.fromEnvironment('SUPABASE_URL');
const _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dart-define (Vercel) tem prioridade; fallback para .env no dev local
  String supabaseUrl = _envUrl.trim();
  String supabaseKey = _envKey.trim();

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    await dotenv.load();
    supabaseUrl = (dotenv.env['SUPABASE_URL'] ?? supabaseUrl).trim();
    supabaseKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? supabaseKey).trim();
  }

  config.supabaseUrl = supabaseUrl;
  config.supabaseAnonKey = supabaseKey;
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  runApp(const ProviderScope(child: MetrificaApp()));
}

class MetrificaApp extends ConsumerWidget {
  const MetrificaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Metrifica Platform',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
