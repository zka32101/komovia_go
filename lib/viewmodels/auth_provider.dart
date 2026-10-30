import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:komovia_core/komovia_core.dart';
import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/utils/entitlement_adapter.dart';

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

/// This [User]'s subscription status as a komovia_core [Entitlement],
/// game-agnostic and shared with komovia_shogi/komovia_chess's own
/// read paths.
final userEntitlementProvider = Provider<Entitlement>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.toEntitlement() ?? const Entitlement.none();
});

/// Boolean flag: is user's account subscription active?
/// Determines paywall display.
///
/// Previously trusted `user.subscriptionActive` as a stored flag forever,
/// never re-checked against `subscriptionEndDate` - nothing client-side
/// ever flips it back to false once a monthly/annual subscription's
/// expiry date passes (there's no Cloud Function that does this
/// server-side either), so an expired subscriber stayed gated-open
/// indefinitely. Now derives from [Entitlement.isCurrentlyActive], which
/// re-checks `expiresAt` against the real current time on every read.
final isSubscriptionActiveProvider = Provider<bool>((ref) {
  return ref.watch(userEntitlementProvider).isCurrentlyActive();
});

/// Whether ads should currently be shown to this user — the single
/// komovia_core `shouldShowAds` check, so `ad_provider.dart`/`ad_banner.dart`
/// read one shared gate instead of each re-deriving
/// `!isSubscriptionActive` independently (see komovia_core's `ad_gate.dart`
/// doc comment for why that duplication is itself a latent regression risk).
final shouldShowAdsProvider = Provider<bool>((ref) {
  return shouldShowAds(ref.watch(userEntitlementProvider));
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

/// Persists the user's chosen preset avatar (komovia_core's `kAvatarIcons`
/// id) and refreshes the cached/watched current user, same pattern as
/// [completeTutorialProvider]/purchase_provider.dart's `_grantEntitlement`.
final updateAvatarProvider = Provider<Future<void> Function(String)>((ref) {
  final firestoreService = FirestoreService();

  return (avatarId) async {
    _logger.i('Updating avatar: $avatarId');
    try {
      final authService = ref.read(authServiceProvider);
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw Exception('No user logged in');
      }

      final updated = user.copyWith(avatarId: avatarId, updatedAt: DateTime.now());
      await firestoreService.saveUser(updated);
      authService.refreshCachedUser(updated);
      ref.invalidate(currentUserProvider);
      _logger.i('✅ Avatar updated');
    } catch (e) {
      _logger.e('❌ Failed to update avatar: $e');
      rethrow;
    }
  };
});
