import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'core/services/navigation_service.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/call_state_provider.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'shared/widgets/floating_call_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KedairekaApp());
}

class KedairekaApp extends StatelessWidget {
  const KedairekaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(authService: AuthService())
            ..add(AuthInitialized()),
        ),
        ChangeNotifierProvider(
          create: (context) => CallStateProvider(),
        ),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: 'KEDAIREKA',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            routerConfig: NavigationService.router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return _AppWithFloatingWidget(child: child);
            },
          );
        },
      ),
    );
  }
}

class _AppWithFloatingWidget extends StatelessWidget {
  final Widget? child;

  const _AppWithFloatingWidget({this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (child != null) child!,
        const Positioned.fill(
          child: _FloatingWidgetOverlay(),
        ),
      ],
    );
  }
}

class _FloatingWidgetOverlay extends StatelessWidget {
  const _FloatingWidgetOverlay();

  @override
  Widget build(BuildContext context) {
    final callState = context.watch<CallStateProvider>();

    // Only show if call is active
    if (!callState.showFloatingWidget) {
      return const SizedBox.shrink();
    }

    // Try to get current route safely
    try {
      final routerState = GoRouterState.of(context);
      if (routerState.uri.path == '/videocall') {
        return const SizedBox.shrink();
      }
    } catch (e) {
      // No route available yet, don't show widget
      return const SizedBox.shrink();
    }

    return const IgnorePointer(
      ignoring: false,
      child: FloatingCallWidget(),
    );
  }
}
