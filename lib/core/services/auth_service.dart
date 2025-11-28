import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard,
  );

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('DEBUG: Attempting to sign in with email: $email');
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('DEBUG: Sign in successful. User: ${result.user?.email}, Email verified: ${result.user?.emailVerified}');
      return result;
    } on FirebaseAuthException catch (e) {
      print('DEBUG: Sign in failed with error code: ${e.code}, message: ${e.message}');
      throw _handleFirebaseAuthException(e);
    }
  }

  Future<UserCredential?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      print('DEBUG: Attempting to create account with email: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('DEBUG: Account created successfully. User: ${userCredential.user?.email}');
      // Automatically send verification email after account creation
      print('DEBUG: Sending verification email...');
      await sendEmailVerification();
      print('DEBUG: Verification email sent successfully');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('DEBUG: Account creation failed with error code: ${e.code}, message: ${e.message}');
      throw _handleFirebaseAuthException(e);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Check if we're on a supported platform for Google Sign-In
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux) {
        throw 'Google Sign-In is not fully supported on this platform. Please use email/password authentication.';
      }

      // Check internet connectivity first
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // Ignore signOut errors, might not be signed in
      }

      // Attempt Google Sign-In with timeout
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Google Sign-In timed out. Please check your internet connection.', const Duration(seconds: 30));
        },
      );

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Failed to get authentication tokens. Please check your internet connection.', const Duration(seconds: 15));
        },
      );

      // Ensure we have valid tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw 'Failed to get authentication tokens from Google. Please try again.';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Firebase authentication timed out. Please check your internet connection.', const Duration(seconds: 15));
        },
      );
    } on TimeoutException catch (e) {
      throw e.message ?? 'Connection timeout. Please check your internet connection and try again.';
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } on PlatformException catch (e) {
      // Handle specific platform exceptions
      switch (e.code) {
        case 'sign_in_failed':
          throw 'Google Sign-In failed. Please check your internet connection and try again.';
        case 'network_error':
          throw 'Network error. Please check your internet connection and try again.';
        case 'sign_in_canceled':
          return null; // User cancelled
        case 'sign_in_required':
          throw 'Sign-in required. Please try again.';
        default:
          throw 'Google Sign-In error: ${e.message ?? e.code}';
      }
    } catch (e) {
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw 'Network connection error. Please check your internet connection and try again.';
      }
      throw 'An error occurred during Google sign in: $e';
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw 'Error signing out: $e';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  Future<void> updateEmail(String email) async {
    try {
      await _auth.currentUser?.updateEmail(email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  Future<void> updatePassword(String password) async {
    try {
      await _auth.currentUser?.updatePassword(password);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Email Verification Methods
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in.';
      }
      if (user.emailVerified) {
        throw 'Email is already verified.';
      }
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      // Handle specific error for already verified or credential issues
      if (e.code == 'invalid-credential' || e.code == 'credential-already-in-use') {
        throw 'Please log out and log back in, then try again.';
      }
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to send verification email: $e';
    }
  }

  Future<void> reloadUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in.';
      }
      await user.reload();
    } on FirebaseAuthException catch (e) {
      // Handle credential issues gracefully
      if (e.code == 'invalid-credential' || e.code == 'user-token-expired') {
        throw 'Your session has expired. Please log in again.';
      }
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to refresh user data: $e';
    }
  }

  bool get isEmailVerified {
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<bool> checkEmailVerified() async {
    try {
      await reloadUser();
      return isEmailVerified;
    } on FirebaseAuthException catch (e) {
      // Handle credential issues by returning current state
      if (e.code == 'invalid-credential' || e.code == 'user-token-expired') {
        throw 'Your session has expired. Please log in again.';
      }
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to check email verification status: $e';
    }
  }

  String _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials and try again.\n\nIf you haven\'t registered yet, please create an account first.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      case 'requires-recent-login':
        return 'This operation is sensitive and requires recent authentication.';
      case 'user-token-expired':
        return 'Your session has expired. Please log in again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        // Log the full error for debugging
        print('DEBUG: Unhandled FirebaseAuthException - Code: ${e.code}, Message: ${e.message}');
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }
}