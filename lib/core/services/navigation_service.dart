import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';  
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/email_verification_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/maps/maps_screen.dart';
import '../../features/maps/saved_sections_screen.dart';
import '../../features/ar/ar_screen.dart';
import '../../features/videocall/videocall_screen.dart';
import '../../features/projects/buildings_map_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
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
        path: AppConstants.emailVerificationRoute,
        name: 'email_verification',
        builder: (context, state) => const EmailVerificationScreen(),
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
        path: AppConstants.buildingsRoute,
        name: 'buildings',
        builder: (context, state) => MainLayout(
          currentRoute: AppConstants.buildingsRoute,
          child: const BuildingsMapScreen(), // Using BuildingsMapScreen with 3D buildings
        ),
      ),
      GoRoute(
        path: '/project/:id',
        name: 'project_detail',
        builder: (context, state) {
          final projectId = state.pathParameters['id'] ?? '';
          return MainLayout(
            currentRoute: AppConstants.buildingsRoute,
            child: ProjectDetailScreen(projectId: projectId),
          );
        },
      ),
      GoRoute(
        path: AppConstants.profileRoute,
        name: 'profile',
        builder: (context, state) => MainLayout(
          currentRoute: AppConstants.profileRoute,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.settingsRoute,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/saved-sections',
        name: 'saved_sections',
        builder: (context, state) => const SavedSectionsScreen(),
      ),
    ],
  );
}