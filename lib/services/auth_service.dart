import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'firestore_service.dart';

class AuthService extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(auth.User? firebaseUser) async {
    if (firebaseUser != null) {
      try {
        _currentUser = await _firestoreService.getUser(firebaseUser.uid);
        notifyListeners();
        } catch (e) {
        debugPrint('Error loading user data: $e');
        _currentUser = null;
        notifyListeners();
      }
    } else {
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String university,
    required String department,
    UserRole role = UserRole.student,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = User(
          id: credential.user!.uid,
          email: email,
          name: name,
          university: university,
          department: department,
          role: role,
          createdAt: DateTime.now(),
        );

        await _firestoreService.createUser(user);
  _currentUser = user;
  notifyListeners();
  debugPrint('Sign up successful for user: ${credential.user!.uid}');
        return null;
      }
    } on auth.FirebaseAuthException catch (e) {
  debugPrint('FirebaseAuthException during sign up: Code=${e.code}, Message=${e.message}');
      return _handleAuthError(e);
    } on TypeError catch (e, stackTrace) {
      // Handle the PigeonUserDetails casting error specifically
  debugPrint('TypeError during sign up (PigeonUserDetails issue): $e');
  debugPrint('Stack trace: $stackTrace');
      
      // Check if user is actually created despite the error
      await Future.delayed(const Duration(milliseconds: 500));
      final currentFirebaseUser = _auth.currentUser;
      if (currentFirebaseUser != null) {
  debugPrint('User created despite error: ${currentFirebaseUser.uid}');
        
        // Create the user document
        try {
          final user = User(
            id: currentFirebaseUser.uid,
            email: email,
            name: name,
            university: university,
            department: department,
            role: role,
            createdAt: DateTime.now(),
          );
          
          await _firestoreService.createUser(user);
          _currentUser = user;
          notifyListeners();
          return null; // Success despite the error
          } catch (firestoreError) {
          debugPrint('Error creating user document: $firestoreError');
          return 'Account created but failed to save profile: $firestoreError';
        }
      }
      
      return 'Registration failed due to internal error: ${e.toString()}\n\nPlease try again or restart the app.';
    } catch (e, stackTrace) {
  debugPrint('Unexpected error during sign up: $e');
  debugPrint('Stack trace: $stackTrace');
      // Return more detailed error message
      return 'Registration failed: ${e.toString()}\n\nThis might be because Email/Password authentication is not enabled in Firebase Console.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return 'Failed to create account';
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Try to sign in
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Verify we got a user
      if (credential.user == null) {
        return 'Login failed: No user returned';
      }
      
  debugPrint('Sign in successful for user: ${credential.user!.uid}');
      
      // Load user data from Firestore
      try {
        _currentUser = await _firestoreService.getUser(credential.user!.uid);
          debugPrint('User data loaded: ${_currentUser?.name}, Role: ${_currentUser?.role}');
        notifyListeners();
      } catch (firestoreError) {
  debugPrint('Warning: Could not load user data from Firestore: $firestoreError');
        // User is authenticated but profile might not exist yet
        // The auth state listener will handle this
      }
      
      return null;
    } on auth.FirebaseAuthException catch (e) {
  debugPrint('FirebaseAuthException during sign in: Code=${e.code}, Message=${e.message}');
      return _handleAuthError(e);
    } on TypeError catch (e, stackTrace) {
      // Handle the PigeonUserDetails casting error specifically
  debugPrint('TypeError during sign in (PigeonUserDetails issue): $e');
  debugPrint('Stack trace: $stackTrace');
      
      // Check if user is actually signed in despite the error
      await Future.delayed(const Duration(milliseconds: 500));
      final currentFirebaseUser = _auth.currentUser;
      if (currentFirebaseUser != null) {
  debugPrint('User is signed in despite error: ${currentFirebaseUser.uid}');
        
        // Try to load user data
        try {
          _currentUser = await _firestoreService.getUser(currentFirebaseUser.uid);
          debugPrint('User data loaded after error: ${_currentUser?.name}, Role: ${_currentUser?.role}');
          notifyListeners();
          } catch (firestoreError) {
          debugPrint('Warning: Could not load user data: $firestoreError');
        }
        
        return null; // Success despite the error
      }
      
      return 'Login failed due to internal error: ${e.toString()}\n\nPlease try again or restart the app.';
    } catch (e, stackTrace) {
  debugPrint('Unexpected error during sign in: $e');
  debugPrint('Stack trace: $stackTrace');
      // Return more detailed error message
      return 'Login failed: ${e.toString()}\n\nThis might be because Email/Password authentication is not enabled in Firebase Console.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on auth.FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  String _handleAuthError(auth.FirebaseAuthException e) {
  debugPrint('Firebase Auth Error - Code: ${e.code}, Message: ${e.message}');
    
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Please contact administrator.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'recaptcha-not-enabled':
      case 'missing-recaptcha-token':
        return 'Security verification failed. Email/Password authentication may not be enabled in Firebase Console.';
      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }
}