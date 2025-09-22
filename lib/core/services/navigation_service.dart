import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/maps/maps_screen.dart';
import '../../features/ar/ar_screen.dart';
import '../../features/videocall/videocall_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../shared/widgets/main_layout.dart';
import '../constants/app_constants.dart';

class NavigationService {
  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.splashRoute,
    routes: [
      GoRoute(
        path: AppConstants.splashRoute,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.authRoute,
        name: 'auth',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppConstants.homeRoute,
        name: 'home',
        builder: (context, state) => MainLayout(
          currentRoute: AppConstants.homeRoute,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.mapsRoute,
        name: 'maps',
        builder: (context, state) => MainLayout(
          currentRoute: AppConstants.mapsRoute,
          child: const MapsScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.arRoute,
        name: 'ar',
        builder: (context, state) => MainLayout(
          currentRoute: AppConstants.arRoute,
          child: const ARScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.videocallRoute,
        name: 'videocall',
        builder: (context, state) => MainLayout(
          currentRoute: AppConstants.videocallRoute,
          child: const VideocallScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.projectsRoute,
        name: 'projects',
        builder: (context, state) => MainLayout(
          currentRoute: AppConstants.projectsRoute,
          child: const ProjectsScreen(),
        ),
      ),
      GoRoute(
        path: '/project/:id',
        name: 'project_detail',
        builder: (context, state) {
          final projectId = state.pathParameters['id'] ?? '';
          return ProjectDetailScreen(projectId: projectId);
        },
      ),
    ],
  );
}