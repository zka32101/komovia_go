import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';

final _logger = Logger();

// ================== SERVICE PROVIDERS ==================

/// Singleton instance of AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ================== AUTH STATE PROVIDERS ==================

/// Stream of current user authentication state
/// Rebuilds UI when user logs in/out
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  _logger.i('Setting up auth state stream');
  return authService.authStateChanges;
});

/// Current user (one-time read, synchronous)
/// Use authStateProvider for reactive updates
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

/// Boolean flag: is user logged in?
/// Useful for routing logic
final isUserLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

/// Boolean flag: is user's account subscription active?
/// Determines paywall display
final isSubscriptionActiveProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.subscriptionActive ?? false;
});

// ================== AUTH ACTIONS ==================

/// Sign up with email and password
final signUpProvider = FutureProvider.family<User, ({String email, String password})>(
  (ref, params) async {
    _logger.i('Sign up initiated: ${params.email}');
    final authService = ref.watch(authServiceProvider);
    try {
      final user = await authService.signUpWithEmail(
        email: params.email,
        password: params.password,
      );
      _logger.i('✅ Sign up successful: ${user.uid}');
      return user;
    } catch (e) {
      _logger.e('❌ Sign up failed: $e');
      rethrow;
    }
  },
);

/// Sign in with email and password
final signInProvider = FutureProvider.family<User, ({String email, String password})>(
  (ref, params) async {
    _logger.i('Sign in initiated: ${params.email}');
    final authService = ref.watch(authServiceProvider);
    try {
      final user = await authService.signInWithEmail(
        email: params.email,
        password: params.password,
      );
      _logger.i('✅ Sign in successful: ${user.uid}');
      return user;
    } catch (e) {
      _logger.e('❌ Sign in failed: $e');
      rethrow;
    }
  },
);

/// Sign in anonymously (for guest play)
final signInAnonymouslyProvider = FutureProvider<User>((ref) async {
  _logger.i('Anonymous sign in initiated');
  final authService = ref.watch(authServiceProvider);
  try {
    final user = await authService.signInAnonymously();
    _logger.i('✅ Anonymous sign in successful: ${user.uid}');
    return user;
  } catch (e) {
    _logger.e('❌ Anonymous sign in failed: $e');
    rethrow;
  }
});

/// Link anonymous account to email/password (upgrade guest to persistent)
final linkAnonymousProvider = FutureProvider.family<void, ({String email, String password})>(
  (ref, params) async {
    _logger.i('Linking anonymous account');
    final authService = ref.watch(authServiceProvider);
    try {
      await authService.linkAnonymousToEmail(
        email: params.email,
        password: params.password,
      );
      _logger.i('✅ Account linking successful');
    } catch (e) {
      _logger.e('❌ Account linking failed: $e');
      rethrow;
    }
  },
);

/// Sign out current user (action provider to allow multiple invocations)
final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    _logger.i('Sign out initiated');
    final authService = ref.read(authServiceProvider);
    try {
      await authService.signOut();
      _logger.i('✅ Sign out successful');
    } catch (e) {
      _logger.e('❌ Sign out failed: $e');
      rethrow;
    }
  };
});

/// Send password reset email
final sendPasswordResetProvider = FutureProvider.family<void, String>(
  (ref, email) async {
    _logger.i('Password reset initiated: $email');
    final authService = ref.watch(authServiceProvider);
    try {
      await authService.sendPasswordResetEmail(email);
      _logger.i('✅ Password reset email sent');
    } catch (e) {
      _logger.e('❌ Password reset failed: $e');
      rethrow;
    }
  },
);

/// Update user display name
final updateDisplayNameProvider = FutureProvider.family<void, String>(
  (ref, displayName) async {
    _logger.i('Display name update initiated: $displayName');
    final authService = ref.watch(authServiceProvider);
    try {
      await authService.updateDisplayName(displayName);
      _logger.i('✅ Display name updated');
    } catch (e) {
      _logger.e('❌ Display name update failed: $e');
      rethrow;
    }
  },
);

/// Delete user account (irreversible, action provider to allow invocation)
final deleteAccountProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    _logger.w('Account deletion initiated');
    final authService = ref.read(authServiceProvider);
    try {
      await authService.deleteAccount();
      _logger.i('✅ Account deleted');
    } catch (e) {
      _logger.e('❌ Account deletion failed: $e');
      rethrow;
    }
  };
});

/// Get Firebase ID token (for debugging)
final getIdTokenProvider = FutureProvider.family<String?, bool>(
  (ref, forceRefresh) async {
    final authService = ref.watch(authServiceProvider);
    try {
      return await authService.getIdToken(forceRefresh: forceRefresh);
    } catch (e) {
      _logger.e('Error getting ID token: $e');
      rethrow;
    }
  },
);

/// Mark tutorial as completed in Firestore
final completeTutorialProvider = Provider<Future<void> Function()>((ref) {
  final firestoreService = FirestoreService();

  return () async {
    _logger.i('Marking tutorial as completed');
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw Exception('No user logged in');
      }

      await firestoreService.saveUser(user.copyWith(tutorialCompleted: true));
      _logger.i('✅ Tutorial marked as completed in Firestore');
    } catch (e) {
      _logger.e('❌ Failed to mark tutorial as completed: $e');
      rethrow;
    }
  };
});
