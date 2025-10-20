import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  late StreamSubscription<User?> _authSubscription;

  AuthBloc({required AuthService authService})
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
      add(AuthInitialized());
    });
  }

  void _onAuthInitialized(AuthInitialized event, Emitter<AuthState> emit) {
    final user = _authService.currentUser;
    print('DEBUG AuthBloc: AuthInitialized triggered. User: ${user?.email}, Current state: $state');

    if (user != null) {
      // Check if this is an email/password user and if email is verified
      // Google Sign-In users bypass verification check as Google verifies emails
      final isEmailPasswordUser = user.providerData.isNotEmpty &&
          user.providerData.any((info) => info.providerId == 'password');

      print('DEBUG AuthBloc: isEmailPasswordUser: $isEmailPasswordUser, emailVerified: ${user.emailVerified}');

      if (isEmailPasswordUser && !user.emailVerified) {
        // Don't authenticate if email is not verified, unless already on a specific flow
        // Only emit unverified state if we're not already in a specific state
        if (state is AuthLoading || state is AuthInitial || state is AuthUnauthenticated) {
          print('DEBUG AuthBloc: Emitting AuthEmailNotVerified');
          emit(AuthEmailNotVerified(user: user));
        } else {
          print('DEBUG AuthBloc: Skipping emit, already in state: $state');
        }
      } else {
        print('DEBUG AuthBloc: Emitting AuthAuthenticated');
        emit(AuthAuthenticated(user: user));
      }
    } else {
      print('DEBUG AuthBloc: No user, emitting AuthUnauthenticated');
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithEmailAndPassword(event.email, event.password);
      // AuthInitialized will be triggered by authStateChanges and will handle
      // email verification check and emit appropriate state
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.createUserWithEmailAndPassword(event.email, event.password);
      // After registration, user needs to verify email
      final user = _authService.currentUser;
      if (user != null) {
        emit(AuthEmailVerificationSent(user: user));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authService.signOut();
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.sendPasswordResetEmail(event.email);
      emit(AuthPasswordResetSent(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onEmailVerificationRequested(
    AuthEmailVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.sendEmailVerification();
      final user = _authService.currentUser;
      if (user != null) {
        emit(AuthEmailVerificationSent(user: user));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onEmailVerificationChecked(
    AuthEmailVerificationChecked event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final isVerified = await _authService.checkEmailVerified();
      final user = _authService.currentUser;

      if (user != null) {
        if (isVerified) {
          emit(AuthAuthenticated(user: user));
        } else {
          emit(AuthEmailNotVerified(user: user));
        }
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}