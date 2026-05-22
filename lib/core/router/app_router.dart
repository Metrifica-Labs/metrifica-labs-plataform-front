import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/career_profile/presentation/career_profile_page.dart';
import '../../features/career_reviews/presentation/career_reviews_page.dart';
import '../../features/certifications/presentation/certifications_page.dart';
import '../../features/events/presentation/events_page.dart';
import '../../features/linkedin/presentation/linkedin_page.dart';
import '../../features/narratives/presentation/narratives_page.dart';
import '../../features/networking/presentation/networking_page.dart';
import '../../features/opportunities/presentation/opportunities_page.dart';
import '../../features/posts/presentation/posts_page.dart';
import '../../shared/widgets/shell_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/profile',
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const CareerProfilePage(),
          ),
          GoRoute(
            path: '/certifications',
            builder: (context, state) => const CertificationsPage(),
          ),
          GoRoute(
            path: '/linkedin',
            builder: (context, state) => const LinkedinPage(),
          ),
          GoRoute(
            path: '/posts',
            builder: (context, state) => const PostsPage(),
          ),
          GoRoute(
            path: '/narratives',
            builder: (context, state) => const NarrativesPage(),
          ),
          GoRoute(
            path: '/reviews',
            builder: (context, state) => const CareerReviewsPage(),
          ),
          GoRoute(
            path: '/opportunities',
            builder: (context, state) => const OpportunitiesPage(),
          ),
          GoRoute(
            path: '/networking',
            builder: (context, state) => const NetworkingPage(),
          ),
          GoRoute(
            path: '/events',
            builder: (context, state) => const EventsPage(),
          ),
        ],
      ),
    ],
  );
});
