import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/audio_visualizer/presentation/audio_visualizer_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/org_picker_page.dart';
import '../../features/copy/presentation/copy_page.dart';
import '../../features/editorial/presentation/editorial_page.dart';
import '../../features/flow/presentation/flow_page.dart';
import '../../features/instagram_n3/presentation/instagram_n3_page.dart';
import '../../features/instagram_post/presentation/instagram_post_page.dart';
import '../../features/module/presentation/module_page.dart';
import '../../features/squad/presentation/squad_page.dart';
import '../../features/video_caption/presentation/video_caption_page.dart';
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
          GoRoute(
            path: '/copy',
            builder: (_, __) => const CopyPage(),
          ),
          GoRoute(
            path: '/editorial',
            builder: (_, __) => const EditorialPage(),
          ),
          GoRoute(
            path: '/instagram-post',
            builder: (_, __) => const InstagramPostPage(),
          ),
          GoRoute(
            path: '/instagram-n3',
            builder: (_, __) => const InstagramN3Page(),
          ),
          GoRoute(
            path: '/audio-visualizer',
            builder: (_, __) => const AudioVisualizerPage(),
          ),
          GoRoute(
            path: '/video-caption',
            builder: (_, __) => const VideoCaptionPage(),
          ),
        ],
      ),
    ],
  );
});
