import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/logger.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../auth/bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Trigger auth initialization
    context.read<AuthBloc>().add(AuthInitialized());
    
    // Add timeout to prevent infinite loading
    await Future.delayed(const Duration(seconds: 2));
    
    // Check current state after initialization
    if (!_hasNavigated && mounted) {
      final currentState = context.read<AuthBloc>().state;
      AppLogger.info('Splash screen timeout - checking current state: $currentState');
      _navigateBasedOnAuthState(currentState);
    }
  }

  void _navigateBasedOnAuthState(AuthState state) {
    if (_hasNavigated || !mounted) return;

    AppLogger.info('Navigating based on auth state: $state');

    if (state is AuthAuthenticated) {
      _hasNavigated = true;
      AppLogger.info('User authenticated, navigating to home');
      context.go(AppConstants.homeRoute);
    } else if (state is AuthUnauthenticated || state is AuthError) {
      _hasNavigated = true;
      AppLogger.info('User not authenticated, navigating to login');
      context.go(AppConstants.authRoute);
    } else if (state is AuthInitial) {
      // If still in initial state after timeout, assume no session and go to login
      _hasNavigated = true;
      AppLogger.info('Still in initial state, navigating to login');
      context.go(AppConstants.authRoute);
    }
    // For AuthLoading, wait for state change
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        _navigateBasedOnAuthState(state);
      },
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Section
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon/Logo
                      Container(
                        width: 150,
                        height: 150,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logos/PIX2LAND.png',
                          fit: BoxFit.contain,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 800.ms)
                          .scale(delay: 200.ms, duration: 600.ms),

                      const SizedBox(height: 24),

                      // App Name
                      Text(
                        AppConstants.appName,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 800.ms)
                          .slideY(begin: 0.3, end: 0),

                      const SizedBox(height: 8),

                      // App Description
                      const Text(
                        'Geodetic AR Mapping',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w300,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 800.ms, duration: 800.ms)
                          .slideY(begin: 0.3, end: 0),
                    ],
                  ),
                ),
              ),

              // Loading Section
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Loading Indicator
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ).animate().fadeIn(delay: 1500.ms),

                    const SizedBox(height: 16),

                    // Loading Text
                    const Text(
                      'Initializing...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(delay: 1800.ms),
                  ],
                ),
              ),

              // Version Section
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  'Version ${AppConstants.appVersion}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ).animate().fadeIn(delay: 2000.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }
}