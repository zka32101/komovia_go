import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/account_data_deletion_service.dart';
import 'package:komovia_go/services/firestore_service.dart';

/// Firebase reports an empty string (not null) for users without a display
/// name, e.g. anonymous ones. Treat it as missing so UI fallbacks apply.
String? _nameOrNull(String? name) =>
    (name == null || name.trim().isEmpty) ? null : name;

/// Service for Firebase Authentication
/// Handles user signup, signin, signout, and session management
class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();
  final Logger _logger = Logger();

  // `currentUser` below is a synchronous getter, so it can't itself await a
  // Firestore read — instead every path that resolves a real User (the auth
  // state stream, sign up/in) caches it here, and `currentUser` serves that
  // cache. Without this, `currentUser` always fabricated a fresh User with
  // subscriptionActive/tutorialCompleted/gamesPlayedCount hardcoded to
  // false/0, which is what authServiceProvider → currentUserProvider is
  // read through nearly everywhere in the app — the paywall would never
  // actually gate anything, since isSubscriptionActiveProvider reads this.
  User? _cachedUser;

  /// Get current user stream (reactive)
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        _logger.i('User signed out');
        _cachedUser = null;
        return null;
      }

      try {
        final firestoreUser = await _firestore.getUser(firebaseUser.uid);
        if (firestoreUser != null) {
          _cachedUser = firestoreUser;
          return firestoreUser;
        }
      } catch (e) {
        _logger.w('Failed to fetch Firestore user, using fallback: $e');
      }

      final fallback = User(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: _nameOrNull(firebaseUser.displayName),
        subscriptionActive: false,
        subscriptionStartDate: DateTime.now(),
        tutorialCompleted: false,
        gamesPlayedCount: 0,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _cachedUser = fallback;
      return fallback;
    });
  }

  /// Get current user (one-time, synchronous). Serves the most recently
  /// cached Firestore-synced profile when available (see [_cachedUser]);
  /// otherwise falls back to a fresh, Firestore-field-less User (e.g. the
  /// brief window before authStateChanges' first event arrives).
  User? get currentUser {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    if (_cachedUser != null && _cachedUser!.uid == firebaseUser.uid) {
      return _cachedUser;
    }

    return User(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: _nameOrNull(firebaseUser.displayName),
      subscriptionActive: false,
      subscriptionStartDate: DateTime.now(),
      tutorialCompleted: false,
      gamesPlayedCount: 0,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Updates the cached profile immediately after a Firestore write this
  /// service didn't itself make (e.g. a purchase or settings change), so
  /// `currentUser`/`currentUserProvider` reflect it without waiting for the
  /// next auth state transition. Callers should also
  /// `ref.invalidate(currentUserProvider)` afterwards.
  void refreshCachedUser(User user) {
    _cachedUser = user;
  }

  /// Sign up with email and password
  ///
  /// Parameters:
  /// - email: User email address
  /// - password: User password (min 6 chars)
  ///
  /// Throws: FirebaseAuthException on error
  Future<User> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    assert(email.isNotEmpty, 'Email cannot be empty');
    assert(password.length >= 6, 'Password must be at least 6 characters');

    try {
      _logger.i('Signing up user: $email');

      firebase_auth.User firebaseUser;
      try {
        firebaseUser = (await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).user!;
        // ignore: avoid_catching_errors
      } on TypeError catch (e) {
        // Same Pigeon cast bug as signInAnonymously below ("List<Object?> is
        // not a subtype of PigeonUserDetails?") — it can fire after account
        // creation already succeeded on any firebase_auth 4.x Android call
        // that returns a UserCredential, not just signInAnonymously.
        final current = _auth.currentUser;
        if (current == null) rethrow;
        _logger.w('createUserWithEmailAndPassword threw a cast error but signed up: $e');
        firebaseUser = current;
      }

      final newUser = User(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: null,
        subscriptionActive: false,
        subscriptionStartDate: DateTime.now(),
        tutorialCompleted: false,
        gamesPlayedCount: 0,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        await _firestore.saveUser(newUser);
        _logger.i('✅ User document created in Firestore');
      } catch (e) {
        _logger.w('Failed to create Firestore user document: $e');
      }

      _logger.i('✅ User signed up: ${firebaseUser.uid}');
      return newUser;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('Auth error during signup: ${e.code}');
      throw AuthServiceException(_parseAuthError(e));
    } catch (e) {
      _logger.e('Unexpected error during signup: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  ///
  /// Parameters:
  /// - email: User email address
  /// - password: User password
  ///
  /// Throws: FirebaseAuthException on error
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    assert(email.isNotEmpty, 'Email cannot be empty');
    assert(password.isNotEmpty, 'Password cannot be empty');

    try {
      _logger.i('Signing in user: $email');

      firebase_auth.User firebaseUser;
      try {
        firebaseUser = (await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).user!;
        // ignore: avoid_catching_errors
      } on TypeError catch (e) {
        // Same Pigeon cast bug as signInAnonymously below.
        final current = _auth.currentUser;
        if (current == null) rethrow;
        _logger.w('signInWithEmailAndPassword threw a cast error but signed in: $e');
        firebaseUser = current;
      }

      try {
        final firestoreUser = await _firestore.getUser(firebaseUser.uid);
        if (firestoreUser != null) {
          _logger.i('✅ User signed in: ${firebaseUser.uid}');
          return firestoreUser;
        }
      } catch (e) {
        _logger.w('Failed to fetch Firestore user: $e');
      }

      _logger.i('✅ User signed in: ${firebaseUser.uid}');
      return User(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: _nameOrNull(firebaseUser.displayName),
        subscriptionActive: false,
        subscriptionStartDate: DateTime.now(),
        tutorialCompleted: false,
        gamesPlayedCount: 0,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('Auth error during signin: ${e.code}');
      throw AuthServiceException(_parseAuthError(e));
    } catch (e) {
      _logger.e('Unexpected error during signin: $e');
      rethrow;
    }
  }

  /// Sign in anonymously (for guest play)
  ///
  /// Useful for allowing players to try the game before creating account
  Future<User> signInAnonymously() async {
    try {
      _logger.i('Signing in anonymously');

      firebase_auth.User firebaseUser;
      try {
        firebaseUser = (await _auth.signInAnonymously()).user!;
        // ignore: avoid_catching_errors
      } on TypeError catch (e) {
        // firebase_auth 4.x on Android can throw a Pigeon cast error
        // ("List<Object?> is not a subtype of PigeonUserDetails?") AFTER the
        // sign-in already succeeded. The session exists, so carry on with it
        // instead of skipping the Firestore user document below.
        final current = _auth.currentUser;
        if (current == null) rethrow;
        _logger.w('signInAnonymously threw a cast error but signed in: $e');
        firebaseUser = current;
      }

      final anonUser = User(
        uid: firebaseUser.uid,
        email: 'anonymous@goen.local',
        displayName: 'Guest Player',
        subscriptionActive: false,
        subscriptionStartDate: DateTime.now(),
        tutorialCompleted: false,
        gamesPlayedCount: 0,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        await _firestore.saveUser(anonUser);
        _logger.i('✅ Anonymous user document created in Firestore');
      } catch (e) {
        _logger.w('Failed to create anonymous user document: $e');
      }

      _logger.i('✅ Anonymous user signed in: ${firebaseUser.uid}');
      return anonUser;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('Auth error during anonymous signin: ${e.code}');
      throw AuthServiceException(_parseAuthError(e));
    } catch (e) {
      _logger.e('Unexpected error during anonymous signin: $e');
      rethrow;
    }
  }

  /// Link anonymous account to email/password
  ///
  /// Call after user decides to create persistent account
  Future<void> linkAnonymousToEmail({
    required String email,
    required String password,
  }) async {
    assert(email.isNotEmpty, 'Email cannot be empty');
    assert(password.length >= 6, 'Password must be at least 6 characters');

    try {
      final user = _auth.currentUser;
      if (user == null || !user.isAnonymous) {
        throw AuthServiceException('No anonymous user to link');
      }

      _logger.i('Linking anonymous account to email: $email');

      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.linkWithCredential(credential);

      _logger.i('✅ Account linked successfully');
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('Auth error during link: ${e.code}');
      throw AuthServiceException(_parseAuthError(e));
    } catch (e) {
      _logger.e('Unexpected error during link: $e');
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      _logger.i('Signing out');
      await _auth.signOut();
      _logger.i('✅ User signed out');
    } catch (e) {
      _logger.e('Error during signout: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    assert(email.isNotEmpty, 'Email cannot be empty');

    try {
      _logger.i('Sending password reset email: $email');
      await _auth.sendPasswordResetEmail(email: email);
      _logger.i('✅ Password reset email sent');
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('Auth error sending reset email: ${e.code}');
      throw AuthServiceException(_parseAuthError(e));
    } catch (e) {
      _logger.e('Unexpected error sending reset email: $e');
      rethrow;
    }
  }

  /// Update user profile display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthServiceException('No user logged in');
      }

      _logger.i('Updating display name: $displayName');
      await user.updateDisplayName(displayName);
      _logger.i('✅ Display name updated');
    } catch (e) {
      _logger.e('Error updating display name: $e');
      rethrow;
    }
  }

  /// Delete user account (caution: irreversible)
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthServiceException('No user logged in');
      }

      _logger.w('Deleting user account: ${user.uid}');
      // Firestore data first: once the auth user is gone the security rules
      // no longer let us touch it. Best effort and idempotent, so a failed
      // auth delete (e.g. requires-recent-login) can simply be retried.
      final failed = await AccountDataDeletionService().deleteAllUserData(user.uid);
      if (failed.isNotEmpty) {
        _logger.w('Account data cleanup incomplete: ${failed.join(', ')}');
      }
      await user.delete();
      _logger.i('✅ Account deleted');
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('Auth error deleting account: ${e.code}');
      throw AuthServiceException(_parseAuthError(e));
    } catch (e) {
      _logger.e('Unexpected error deleting account: $e');
      rethrow;
    }
  }

  /// Get Firebase auth token (for debugging)
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      return await user.getIdToken(forceRefresh);
    } catch (e) {
      _logger.e('Error getting ID token: $e');
      rethrow;
    }
  }

  /// Parse Firebase auth error into user-friendly message
  String _parseAuthError(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'Email is already registered.';
      case 'invalid-email':
        return 'Email address is invalid.';
      case 'user-disabled':
        return 'User account has been disabled.';
      case 'user-not-found':
        return 'User not found. Check your email.';
      case 'wrong-password':
        return 'Password is incorrect.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}

/// Custom exception for Auth errors
class AuthServiceException implements Exception {
  final String message;

  AuthServiceException(this.message);

  @override
  String toString() => 'AuthServiceException: $message';
}
