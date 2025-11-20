import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/backend_auth_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/models/backend_user_model.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final BackendAuthService _authService;
  late StreamSubscription<BackendUser?> _authSubscription;

  // Add deduplication timers
  DateTime? _lastInitializedEventTime;
  static const Duration _eventDebounceDelay = Duration(milliseconds: 500);

  AuthBloc({required BackendAuthService authService})
      : _authService = authService,
        super(AuthInitial()) {

    on<AuthInitialized>(_onAuthInitialized);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthEmailVerificationRequested>(_onEmailVerificationRequested);
    on<AuthEmailVerificationChecked>(_onEmailVerificationChecked);

    _authSubscription = _authService.authStateChanges.listen((user) {
      _debouncedAddAuthInitialized();
    });
  }

  void _debouncedAddAuthInitialized() {
    final now = DateTime.now();

    // Skip if we've already processed an AuthInitialized event recently
    if (_lastInitializedEventTime != null &&
        now.difference(_lastInitializedEventTime!) < _eventDebounceDelay) {
      AppLogger.bloc('Skipping AuthInitialized event due to debounce');
      return;
    }

    _lastInitializedEventTime = now;
    add(AuthInitialized());
  }

  Future<void> _onAuthInitialized(AuthInitialized event, Emitter<AuthState> emit) async {
    final user = _authService.currentUser;
    AppLogger.bloc('AuthInitialized triggered. User: ${user?.email}, Current state: $state');

    if (user != null) {
      // Check if email is verified for email users
      // For backend auth, we need to check the backend data
      if (_authService.authProvider == 'email' && !_authService.isEmailVerified) {
        // Don't authenticate if email is not verified
        if (state is AuthLoading || state is AuthInitial || state is AuthUnauthenticated) {
          AppLogger.bloc('Emitting AuthEmailNotVerified');
          emit(AuthEmailNotVerified(user: user));
        } else {
          AppLogger.bloc('Skipping emit, already in state: $state');
        }
      } else {
        // Only emit if not already authenticated with the same user
        if (state is! AuthAuthenticated || (state as AuthAuthenticated).user.uid != user.uid) {
          AppLogger.bloc('Emitting AuthAuthenticated');
          emit(AuthAuthenticated(user: user));
        } else {
          AppLogger.bloc('Already authenticated with same user, skipping emit');
        }
      }
    } else {
      // Try to initialize the backend service to check for existing session
      try {
        AppLogger.auth('Initializing backend service...');
        await _authService.initialize();
        final initializedUser = _authService.currentUser;
        if (initializedUser != null) {
          AppLogger.auth('Backend service initialized with user: ${initializedUser.email}');
          emit(AuthAuthenticated(user: initializedUser));
          return;
        }
      } catch (e, stackTrace) {
        AppLogger.auth('Backend service initialization failed', error: e, stackTrace: stackTrace);
      }

      // Don't emit unauthenticated if we're already authenticated or in a transient state
      if (state is AuthUnauthenticated) {
        AppLogger.bloc('Already unauthenticated, skipping emit');
        return;
      }

      if (state is! AuthAuthenticated &&
          state is! AuthEmailVerificationSent &&
          state is! AuthEmailNotVerified &&
          state is! AuthPasswordResetSent) {
        AppLogger.bloc('No user, emitting AuthUnauthenticated');
        emit(AuthUnauthenticated());
      } else {
        AppLogger.bloc('User is null but maintaining current state: $state');
      }
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.auth('Login requested for email: ${event.email}');
    emit(AuthLoading());
    try {
      await _authService.signInWithEmailAndPassword(event.email, event.password);
      AppLogger.auth('Login successful for: ${event.email}');
      // AuthInitialized will be triggered by authStateChanges and will handle
      // email verification check and emit appropriate state
    } catch (e, stackTrace) {
      AppLogger.auth('Login failed for: ${event.email}', error: e, stackTrace: stackTrace);
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.auth('Registration requested for email: ${event.email}, name: ${event.name}');
    emit(AuthLoading());
    try {
      await _authService.registerWithEmailAndPassword(event.name, event.email, event.password);
      AppLogger.auth('Registration successful for: ${event.email}');
      // After registration, check if user needs email verification
      final user = _authService.currentUser;
      if (user != null) {
        if (_authService.authProvider == 'email' && !_authService.isEmailVerified) {
          AppLogger.auth('Email verification required for: ${event.email}');
          emit(AuthEmailVerificationSent(user: user));
        } else {
          AppLogger.auth('User authenticated after registration: ${event.email}');
          emit(AuthAuthenticated(user: user));
        }
      }
    } catch (e, stackTrace) {
      AppLogger.auth('Registration failed for: ${event.email}', error: e, stackTrace: stackTrace);
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.auth('Google sign-in requested');
    emit(AuthLoading());
    try {
      await _authService.signInWithGoogle();
      AppLogger.auth('Google sign-in successful');
    } catch (e, stackTrace) {
      AppLogger.auth('Google sign-in failed', error: e, stackTrace: stackTrace);
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.auth('Logout requested');
    try {
      await _authService.signOut();
      AppLogger.auth('Sign out successful');
      // Explicitly emit unauthenticated state after logout
      emit(AuthUnauthenticated());
      AppLogger.bloc('Emitted AuthUnauthenticated');
    } catch (e, stackTrace) {
      AppLogger.auth('Logout error', error: e, stackTrace: stackTrace);
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.auth('Password reset requested for: ${event.email}');
    emit(AuthLoading());
    try {
      await _authService.sendPasswordResetEmail(event.email);
      AppLogger.auth('Password reset email sent to: ${event.email}');
      emit(AuthPasswordResetSent(email: event.email));
    } catch (e, stackTrace) {
      AppLogger.auth('Password reset failed for: ${event.email}', error: e, stackTrace: stackTrace);
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onEmailVerificationRequested(
    AuthEmailVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.auth('Email verification requested');
    emit(AuthLoading());
    try {
      await _authService.sendEmailVerification();
      AppLogger.auth('Email verification sent');
      final user = _authService.currentUser;
      if (user != null) {
        emit(AuthEmailVerificationSent(user: user));
      }
    } catch (e, stackTrace) {
      AppLogger.auth('Email verification failed', error: e, stackTrace: stackTrace);
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onEmailVerificationChecked(
    AuthEmailVerificationChecked event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.auth('Email verification check requested');
    emit(AuthLoading());
    try {
      final isVerified = await _authService.checkEmailVerified();
      final user = _authService.currentUser;

      if (user != null) {
        if (isVerified) {
          AppLogger.auth('Email verified successfully for: ${user.email}');
          emit(AuthAuthenticated(user: user));
        } else {
          AppLogger.auth('Email not verified for: ${user.email}');
          emit(AuthEmailNotVerified(user: user));
        }
      }
    } catch (e, stackTrace) {
      AppLogger.auth('Email verification check failed', error: e, stackTrace: stackTrace);
      emit(AuthError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    _authService.dispose();
    return super.close();
  }
}