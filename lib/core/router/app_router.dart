import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/org_picker_page.dart';
import '../../features/flow/presentation/flow_page.dart';
import '../../features/module/presentation/module_page.dart';
import '../../features/squad/presentation/squad_page.dart';
import '../../shared/widgets/shell_scaffold.dart';
import '../providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/org-picker',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/org-picker',
        builder: (_, __) => const OrgPickerPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/flows/:slug',
            builder: (context, state) =>
                FlowPage(slug: state.pathParameters['slug']!),
          ),
          GoRoute(
            path: '/modules/:slug',
            builder: (context, state) =>
                ModulePage(slug: state.pathParameters['slug']!),
          ),
          GoRoute(
            path: '/squads/:slug',
            builder: (context, state) =>
                SquadPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
    ],
  );
});
