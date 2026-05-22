import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/flow/presentation/flow_page.dart';
import '../../features/module/presentation/module_page.dart';
import '../../shared/widgets/shell_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/flows/proposta-comercial',
    routes: [
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
        ],
      ),
    ],
  );
});
