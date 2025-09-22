import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/maps/maps_screen.dart';
import '../../features/ar/ar_screen.dart';
import '../../features/videocall/videocall_screen.dart';
import '../../features/projects/projects_screen.dart';
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
        path: AppConstants.homeRoute,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppConstants.mapsRoute,
        name: 'maps',
        builder: (context, state) => const MapsScreen(),
      ),
      GoRoute(
        path: AppConstants.arRoute,
        name: 'ar',
        builder: (context, state) => const ARScreen(),
      ),
      GoRoute(
        path: AppConstants.videocallRoute,
        name: 'videocall',
        builder: (context, state) => const VideocallScreen(),
      ),
      GoRoute(
        path: AppConstants.projectsRoute,
        name: 'projects',
        builder: (context, state) => const ProjectsScreen(),
      ),
    ],
  );
}