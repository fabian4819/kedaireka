import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'firebase_options.dart';
import 'core/services/navigation_service.dart';
import 'core/services/backend_auth_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/call_state_provider.dart';
import 'core/utils/logger.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'shared/widgets/floating_call_widget.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter Error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Set up platform error handler for newer Flutter versions
  try {
    foundation.PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error(
        'Platform Error: $error',
        error: error,
        stackTrace: stack,
      );
      return true;
    };
  } catch (e) {
    // Fallback for older Flutter versions - just log the error
    AppLogger.warning('Could not set up PlatformDispatcher error handler: $e');
  }

  // Initialize Mapbox
  try {
    AppLogger.info('Initializing Mapbox...');
    mb.MapboxOptions.setAccessToken(MapboxConfig.accessToken);
    AppLogger.info('Mapbox initialized successfully');
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize Mapbox', error: e, stackTrace: stackTrace);
  }

  try {
    AppLogger.info('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase initialized successfully');
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize Firebase', error: e, stackTrace: stackTrace);
    rethrow;
  }

  AppLogger.info('Starting Kedaireka app...');
  runApp(const KedairekaApp());
}

class KedairekaApp extends StatelessWidget {
  const KedairekaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(authService: BackendAuthService()),
        ),
        ChangeNotifierProvider(
          create: (context) => CallStateProvider(),
        ),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: 'Pix2Land',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            routerConfig: NavigationService.router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                AppLogger.error(
                  'Error Widget: ${errorDetails.exception}',
                  error: errorDetails.exception,
                  stackTrace: errorDetails.stack,
                );
                return MaterialApp(
                  home: Scaffold(
                    backgroundColor: Colors.red[50],
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red[700], size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'Something went wrong',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Check the terminal for detailed error logs',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.red[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                // Restart the app
                                runApp(const KedairekaApp());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Restart App'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              };
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
    } catch (e, stackTrace) {
      AppLogger.error('Error getting router state for floating widget', error: e, stackTrace: stackTrace);
      // No route available yet, don't show widget
      return const SizedBox.shrink();
    }

    return const IgnorePointer(
      ignoring: false,
      child: FloatingCallWidget(),
    );
  }
}
