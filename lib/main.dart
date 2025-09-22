import 'package:flutter/material.dart';
import 'core/services/navigation_service.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const KedairekaApp());
}

class KedairekaApp extends StatelessWidget {
  const KedairekaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KEDAIREKA',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: NavigationService.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
