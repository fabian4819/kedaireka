import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _shouldShowBottomNav(currentRoute)
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primaryColor,
              unselectedItemColor: Colors.grey,
              currentIndex: _getCurrentIndex(currentRoute),
              onTap: (index) => _onBottomNavTap(context, index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: 'Maps',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.view_in_ar),
                  label: 'AR',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.video_call),
                  label: 'Video',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.folder),
                  label: 'Projects',
                ),
              ],
            )
          : null,
    );
  }

  bool _shouldShowBottomNav(String route) {
    // Show bottom nav on main app screens, hide on auth and splash
    const mainRoutes = [
      AppConstants.homeRoute,
      AppConstants.mapsRoute,
      AppConstants.arRoute,
      AppConstants.videocallRoute,
      AppConstants.projectsRoute,
    ];
    return mainRoutes.contains(route);
  }

  int _getCurrentIndex(String route) {
    switch (route) {
      case AppConstants.homeRoute:
        return 0;
      case AppConstants.mapsRoute:
        return 1;
      case AppConstants.arRoute:
        return 2;
      case AppConstants.videocallRoute:
        return 3;
      case AppConstants.projectsRoute:
        return 4;
      default:
        return 0;
    }
  }

  void _onBottomNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppConstants.homeRoute);
        break;
      case 1:
        context.go(AppConstants.mapsRoute);
        break;
      case 2:
        context.go(AppConstants.arRoute);
        break;
      case 3:
        context.go(AppConstants.videocallRoute);
        break;
      case 4:
        context.go(AppConstants.projectsRoute);
        break;
    }
  }
}