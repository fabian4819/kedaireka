import 'package:equatable/equatable.dart';
import '../../../core/models/backend_user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final BackendUser user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object> get props => [message];
}

class AuthPasswordResetSent extends AuthState {
  final String email;

  const AuthPasswordResetSent({required this.email});

  @override
  List<Object> get props => [email];
}

class AuthEmailNotVerified extends AuthState {
  final BackendUser user;

  const AuthEmailNotVerified({required this.user});

  @override
  List<Object> get props => [user];
}

class AuthEmailVerificationSent extends AuthState {
  final BackendUser user;

  const AuthEmailVerificationSent({required this.user});

  @override
  List<Object> get props => [user];
}