import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/media/avatar_image_helper.dart';
import '../chat/cometchat_auth_service.dart';

/// User-facing copy for OTP verify failures from Cloud Functions.
String otpVerifyErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'invalid-argument':
        final msg = error.message?.toLowerCase() ?? '';
        if (msg.contains('incorrect')) {
          return 'Incorrect code. Double-check the 6 digits or tap Re-send code.';
        }
        return error.message ?? 'Invalid code.';
      case 'not-found':
        return 'No active code for this email. Tap Re-send code and use the newest code.';
      case 'failed-precondition':
        return error.message ?? 'Code expired. Tap Re-send code.';
      default:
        return error.message ?? 'Could not verify. Try Re-send code.';
    }
  }
  return 'Could not verify. Tap Re-send code and try again.';
}

/// User-facing copy for OTP request failures from Cloud Functions.
String otpRequestErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'Failed to send code. Please try again.';
  }
  return 'Failed to send code. Please try again.';
}

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Signed-in user's Firestore `users/{uid}` document (null if signed out or no doc).
final currentUserProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snap) => snap.data());
    },
    loading: () => Stream.value(null),
    error: (Object err, StackTrace st) => Stream.value(null),
  );
});

/// Fetch any user's profile by UID
final userProfileFutureProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, uid) async {
      if (uid.trim().isEmpty) return null;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return snap.data();
    });

/// Stream any user's profile by UID (real-time updates)
/// Handles case-insensitive lookup (e.g. for CometChat's lowercase UIDs).
final userProfileStreamProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) async* {
      if (uid.trim().isEmpty) {
        yield null;
        return;
      }

      final db = FirebaseFirestore.instance;
      // Fast path: try exact match first
      final snap = await db.collection('users').doc(uid).get();
      if (snap.exists) {
        yield* db.collection('users').doc(uid).snapshots().map((s) => s.data());
        return;
      }

      // Slow path: find real mixed-case UID for CometChat integration
      final qs = await db.collection('users').get();
      String? realUid;
      for (final doc in qs.docs) {
        if (doc.id.toLowerCase() == uid.toLowerCase()) {
          realUid = doc.id;
          break;
        }
      }

      if (realUid != null) {
        yield* db
            .collection('users')
            .doc(realUid)
            .snapshots()
            .map((s) => s.data());
      } else {
        yield null;
      }
    });

/// Firestore `institutions/{id}.allowed_domains` (lowercased) for client-side validation.
const String kDefaultInstitutionDocId = 'eduvos_01';

final allowedEmailDomainsProvider = FutureProvider<List<String>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('institutions')
      .doc(kDefaultInstitutionDocId)
      .get();
  if (!snap.exists) {
    throw StateError('Institution configuration not found.');
  }
  final raw = snap.data()?['allowed_domains'];
  if (raw is! List) {
    throw StateError('Institution allowed_domains missing or invalid.');
  }
  return raw.map((e) => e.toString().trim().toLowerCase()).toList();
});

/// Passed to [AuthController.requestOtp] so the callable can enforce login vs sign-up rules.
enum AuthOtpFlow { login, signup }

/// Fallback tags if `institutions/{id}` has no `interests` field.
const List<String> kDefaultInterestTags = [
  'dancing',
  'community',
  'social',
  'gaming',
  'e-sports',
  'movies',
  'art',
  'education',
  'IT',
  'live music',
  'festivals',
  'theater',
  'arts & crafts',
  'films',
  'photography',
  'fitness',
  'yoga',
  'hiking',
  'swimming',
  'farmers market',
  'wine tasting',
  'afrikaans',
  'block parties',
  'cooking',
  'night life',
  'fashion',
  'STEM',
  'computer science',
  'coding',
  'history',
  'board games',
  'volunteering',
];

class InstitutionSignupData {
  final List<String> campuses;
  final List<String> interests;

  const InstitutionSignupData({
    required this.campuses,
    required this.interests,
  });
}

List<String> _parseFirestoreStringList(dynamic raw) {
  if (raw is! List) return [];
  final out = <String>[];
  for (final e in raw) {
    if (e is String) {
      final t = e.trim();
      if (t.isNotEmpty) out.add(t);
    } else if (e is Map) {
      final n = e['name'] ?? e['title'] ?? e['label'];
      if (n != null) {
        final t = n.toString().trim();
        if (t.isNotEmpty) out.add(t);
      }
    }
  }
  return out;
}

Future<List<String>> _campusesFromSubcollection() async {
  try {
    final qs = await FirebaseFirestore.instance
        .collection('institutions')
        .doc(kDefaultInstitutionDocId)
        .collection('campuses')
        .get();
    final out = <String>[];
    for (final d in qs.docs) {
      final m = d.data();
      final n = m['name'] ?? m['title'] ?? m['label'] ?? d.id;
      final t = n.toString().trim();
      if (t.isNotEmpty) out.add(t);
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      debugPrint(
        'Bloom: cannot read institutions/$kDefaultInstitutionDocId/campuses — '
        'deploy firestore.rules or add a `campuses` array on the institution doc.',
      );
    } else {
      debugPrint('Bloom: campuses subcollection read failed: $e');
    }
    return [];
  }
}

Future<List<String>> _interestsFromSubcollection() async {
  try {
    final qs = await FirebaseFirestore.instance
        .collection('institutions')
        .doc(kDefaultInstitutionDocId)
        .collection('interests')
        .get();
    final out = <String>[];
    for (final d in qs.docs) {
      final m = d.data();
      final n = m['name'] ?? m['label'] ?? m['title'] ?? d.id;
      final t = n.toString().trim();
      if (t.isNotEmpty) out.add(t);
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      debugPrint(
        'Bloom: cannot read institutions/$kDefaultInstitutionDocId/interests — '
        'deploy firestore.rules or add an `interests` array on the institution doc.',
      );
    } else {
      debugPrint('Bloom: interests subcollection read failed: $e');
    }
    return [];
  }
}

/// Campuses and interest tags from `institutions/{kDefaultInstitutionDocId}`.
/// Supports array fields on the doc and/or `campuses` / `interests` subcollections.
final institutionSignupDataProvider = FutureProvider<InstitutionSignupData>((
  ref,
) async {
  final snap = await FirebaseFirestore.instance
      .collection('institutions')
      .doc(kDefaultInstitutionDocId)
      .get();
  if (!snap.exists) {
    return const InstitutionSignupData(
      campuses: [],
      interests: kDefaultInterestTags,
    );
  }
  final data = snap.data()!;
  var campuses = _parseFirestoreStringList(
    data['campuses'] ?? data['campus_list'] ?? data['locations'],
  );
  if (campuses.isEmpty) {
    campuses = await _campusesFromSubcollection();
  }
  var interests = _parseFirestoreStringList(
    data['interests'] ?? data['interest_tags'] ?? data['interestOptions'],
  );
  if (interests.isEmpty) {
    interests = await _interestsFromSubcollection();
  }
  if (interests.isEmpty) {
    interests = List<String>.from(kDefaultInterestTags);
  }
  return InstitutionSignupData(campuses: campuses, interests: interests);
});

/// Local-part sanity check + domain must appear in [allowedDomainsLower].
bool isEmailAllowedForInstitution(
  String email,
  List<String> allowedDomainsLower,
) {
  final trimmed = email.trim();
  final at = trimmed.indexOf('@');
  if (at <= 0 || at == trimmed.length - 1) return false;
  final local = trimmed.substring(0, at);
  final domain = trimmed.substring(at + 1).toLowerCase();
  if (!RegExp(r'^[a-zA-Z0-9._%+-]+$').hasMatch(local)) return false;
  return allowedDomainsLower.contains(domain);
}

// ==========================================
// ==========================================

class OtpTimerState {
  final int secondsRemaining;
  final bool isRunning;

  OtpTimerState({required this.secondsRemaining, required this.isRunning});

  bool get canResend => secondsRemaining == 0 && !isRunning;
  String get formattedTime {
    final mins = (secondsRemaining / 60).floor();
    final secs = secondsRemaining % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class OtpTimerNotifier extends Notifier<OtpTimerState> {
  Timer? _timer;

  @override
  OtpTimerState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return OtpTimerState(secondsRemaining: 90, isRunning: false);
  }

  void start() {
    state = OtpTimerState(secondsRemaining: 90, isRunning: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining > 0) {
        state = OtpTimerState(
          secondsRemaining: state.secondsRemaining - 1,
          isRunning: true,
        );
      } else {
        stop();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    state = OtpTimerState(
      secondsRemaining: state.secondsRemaining,
      isRunning: false,
    );
  }
}

final otpTimerProvider = NotifierProvider<OtpTimerNotifier, OtpTimerState>(() {
  return OtpTimerNotifier();
});

// ==========================================
// AUTH CONTROLLER (Cloud Functions & Firestore)
// ==========================================

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> validateStudentEmail(String email) async {
    state = const AsyncLoading();
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
      final callable = functions.httpsCallable('validateStudentEmail');
      await callable.call(<String, dynamic>{'email': email.trim()});
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> validateUsername(String username) async {
    state = const AsyncLoading();
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
      final callable = functions.httpsCallable('validateUsername');
      await callable.call(<String, dynamic>{'username': username.trim()});
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// [flow] is sent as `authFlow` to the `requestOtp` callable (pre-flight lives there).
  Future<void> requestOtp(String email, AuthOtpFlow flow) async {
    state = const AsyncLoading();
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
      final callable = functions.httpsCallable('requestOtp');
      await callable.call(<String, dynamic>{
        'email': email.trim(),
        'authFlow': flow == AuthOtpFlow.login ? 'login' : 'signup',
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    state = const AsyncLoading();
    try {
      // Pointing to the Johannesburg 2nd Gen server
      final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
      final callable = functions.httpsCallable('verifyOtp');

      final result = await callable.call(<String, dynamic>{
        'email': email.trim(),
        'otp': otp.trim(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final token = data['token'] as String?;
      final isNewUser = data['isNewUser'] == true;

      if (token == null) {
        throw Exception("Authentication failed: No token received from server");
      }

      await FirebaseAuth.instance.signInWithCustomToken(token);

      // Chat is optional at login — never block Firebase sign-in if CometChat fails.
      if (!isNewUser) {
        try {
          await CometChatAuthService.loginWithFirebaseSession();
        } catch (e, st) {
          debugPrint('CometChat login after OTP skipped: $e\n$st');
        }
      }

      state = const AsyncData(null);
      return isNewUser;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Creates the permanent Firestore user profile record using the collected form data.
  // This must be called after the user has successfully authenticated with Firebase via OTP.
  Future<void> createUserProfile(SignUpFormState formData) async {
    state = const AsyncLoading();
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('User must be authenticated to create a profile.');
      }

      // --- 1. SET GENDER ---
      String standardizedGender = 'prefer not to say';
      final rawGender = formData.gender.trim().toLowerCase();
      if (rawGender == 'female') {
        standardizedGender = 'female';
      } else if (rawGender == 'male') {
        standardizedGender = 'male';
      }

      // --- 2. CONVERT BIRTHDAY TO TIMESTAMP (UI: "1999 / Jan / 03" or "1999 / JAN / 03") ---
      Timestamp? birthdateTimestamp;
      try {
        final parts = formData.birthday.split(' / ');
        if (parts.length == 3) {
          final year = int.parse(parts[0].trim());
          final day = int.parse(parts[2].trim());

          const months = {
            'JAN': 1,
            'FEB': 2,
            'MAR': 3,
            'APR': 4,
            'MAY': 5,
            'JUN': 6,
            'JUL': 7,
            'AUG': 8,
            'SEP': 9,
            'OCT': 10,
            'NOV': 11,
            'DEC': 12,
          };
          final monthToken = parts[1].trim();
          final monthKey = monthToken.length >= 3
              ? monthToken.substring(0, 3).toUpperCase()
              : monthToken.toUpperCase();
          final month = months[monthKey] ?? 1;

          final date = DateTime.utc(year, month, day);
          birthdateTimestamp = Timestamp.fromDate(date);
        }
      } catch (e) {
        debugPrint("Date parsing failed: $e");
      }

      var profileImageUrl = '';
      String? largeUrl;
      String? smallUrl;
      final avatarResult = formData.avatarProcessResult;

      if (avatarResult != null) {
        final largeUpload = await _uploadProfileImageVariant(currentUser.uid, File(avatarResult.largePath), 'large');
        final mediumUpload = await _uploadProfileImageVariant(currentUser.uid, File(avatarResult.mediumPath), 'medium');
        final smallUpload = await _uploadProfileImageVariant(currentUser.uid, File(avatarResult.smallPath), 'small');
        
        if (mediumUpload != null) {
          profileImageUrl = mediumUpload;
          largeUrl = largeUpload;
          smallUrl = smallUpload;
        }
      }

      // --- 4. FIRESTORE WRITE ---
      final emailNormalized = formData.email.trim().toLowerCase();
      await firestore.collection('users').doc(currentUser.uid).set({
        'uid': currentUser.uid,
        'email': emailNormalized,
        'username': formData.username.trim(),
        'name': formData.name.trim(),
        'birthdate': birthdateTimestamp,
        'gender': standardizedGender,
        'institution': kDefaultInstitutionDocId,
        'campus': formData.campus,
        'profile_image_url': profileImageUrl,
        'profile_image_large_url': largeUrl,
        'profile_image_medium_url': profileImageUrl,
        'profile_image_small_url': smallUrl,
        'interests': formData.interests,
        'is_verified': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      await CometChatAuthService.registerAndLogin(name: formData.name.trim());

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signOut({bool clearSignUpForm = true}) async {
    await CometChatAuthService.logout();
    await FirebaseAuth.instance.signOut();
    if (clearSignUpForm) {
      ref.read(signUpFormProvider.notifier).clearForm();
    }
  }

  Future<String?> _uploadProfileImageVariant(String uid, File file, String size) async {
    final bytes = await file.readAsBytes();

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(uid)
        .child('profile_pic_$size.webp');

    await storageRef.putData(
      bytes,
      SettableMetadata(contentType: 'image/webp'),
    );

    return await storageRef.getDownloadURL();
  }

  Future<void> updateUserProfile(
    Map<String, dynamic> updates, {
    AvatarProcessResult? imageResult,
    File? imageFile, // Fallback
  }) async {
    state = const AsyncLoading();
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('User must be authenticated to update profile.');
      }

      final data = {...updates, 'updated_at': FieldValue.serverTimestamp()};

      if (imageResult != null) {
        final largeUrl = await _uploadProfileImageVariant(currentUser.uid, File(imageResult.largePath), 'large');
        final mediumUrl = await _uploadProfileImageVariant(currentUser.uid, File(imageResult.mediumPath), 'medium');
        final smallUrl = await _uploadProfileImageVariant(currentUser.uid, File(imageResult.smallPath), 'small');
        
        if (mediumUrl != null) {
          data['profile_image_url'] = mediumUrl; // Default
          data['profile_image_large_url'] = largeUrl;
          data['profile_image_medium_url'] = mediumUrl;
          data['profile_image_small_url'] = smallUrl;
        }
      } else if (imageFile != null) {
        final imageUrl = await _uploadProfileImageVariant(currentUser.uid, imageFile, 'medium');
        if (imageUrl != null) {
          data['profile_image_url'] = imageUrl;
          data['profile_image_medium_url'] = imageUrl;
        }
      }

      await firestore.collection('users').doc(currentUser.uid).update(data);

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Deletes the current Firebase Auth user (ghost account) and clears the form state.
  /// Used when a user cancels the registration flow midway.
  Future<void> rollbackRegistration() async {
    state = const AsyncLoading();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Use the server-side deletion to ensure both Auth and Firestore are cleaned up
        final functions = FirebaseFunctions.instanceFor(
          region: 'africa-south1',
        );
        final callable = functions.httpsCallable('deleteUserAccount');
        await callable.call();

        await signOut();
      } else {
        await signOut();
      }
      state = const AsyncData(null);
    } catch (e) {
      debugPrint("Auth rollback failed: $e");
      await signOut();
      state = const AsyncData(null);
    }
  }

  /// Deletes the current authenticated user's account by calling the backend
  /// Cloud Function and signing out.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final functions = FirebaseFunctions.instanceFor(
          region: 'africa-south1',
        );
        final callable = functions.httpsCallable('deleteUserAccount');
        await callable.call();
        await signOut();
      } else {
        throw Exception("No user authenticated.");
      }
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

// ==========================================
// EMAIL OTP CONTROLLER (Custom Token Flow)
// ==========================================

class EmailOtpController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> sendOtp(String email, AuthOtpFlow flow) async {
    state = const AsyncLoading();
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
      final callable = functions.httpsCallable('requestEmailOtp');
      await callable.call(<String, dynamic>{
        'email': email.trim(),
        'authFlow': flow == AuthOtpFlow.login ? 'login' : 'signup',
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> verifyOtpAndSignIn(String email, String otp) async {
    state = const AsyncLoading();
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
      final callable = functions.httpsCallable('verifyEmailOtp');

      final result = await callable.call(<String, dynamic>{
        'email': email.trim(),
        'otp': otp.trim(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final token = data['token'] as String?;
      final isNewUser = data['isNewUser'] == true;

      if (token == null) {
        throw Exception("Authentication failed: No token received from server");
      }

      await FirebaseAuth.instance.signInWithCustomToken(token);

      if (!isNewUser) {
        try {
          await CometChatAuthService.loginWithFirebaseSession();
        } catch (e, st) {
          debugPrint('CometChat login after OTP skipped: $e\\n$st');
        }
      }

      state = const AsyncData(null);
      return isNewUser;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final emailOtpControllerProvider =
    AsyncNotifierProvider<EmailOtpController, void>(() {
      return EmailOtpController();
    });

// ==========================================
// ==========================================

class SignUpFormState {
  final String email;
  final String username;
  final String name;
  final String birthday;
  final String gender;
  final String campus;
  final AvatarProcessResult? avatarProcessResult;
  final List<String> interests;

  SignUpFormState({
    this.email = '',
    this.username = '',
    this.name = '',
    this.birthday = '',
    this.gender = 'prefer not to say', // Enforces UI default
    this.campus = '',
    this.avatarProcessResult,
    this.interests = const [],
  });

  SignUpFormState copyWith({
    String? email,
    String? username,
    String? name,
    String? birthday,
    String? gender,
    String? campus,
    AvatarProcessResult? avatarProcessResult,
    bool clearAvatar = false,
    List<String>? interests,
  }) {
    return SignUpFormState(
      email: email ?? this.email,
      username: username ?? this.username,
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      campus: campus ?? this.campus,
      avatarProcessResult: clearAvatar ? null : (avatarProcessResult ?? this.avatarProcessResult),
      interests: interests ?? this.interests,
    );
  }
}

class SignUpFormNotifier extends Notifier<SignUpFormState> {
  @override
  SignUpFormState build() {
    return SignUpFormState();
  }

  void updateEmail(String email) => state = state.copyWith(email: email);

  void updateDetails({
    String? username,
    String? name,
    String? birthday,
    String? gender,
  }) {
    state = state.copyWith(
      username: username ?? state.username,
      name: name ?? state.name,
      birthday: birthday ?? state.birthday,
      gender: gender ?? state.gender,
    );
  }

  void updateCampus(String campus) => state = state.copyWith(campus: campus);
  void updateAvatar(AvatarProcessResult? result) =>
      state = state.copyWith(avatarProcessResult: result, clearAvatar: result == null);

  void toggleInterest(String interest) {
    if (state.interests.contains(interest)) {
      state = state.copyWith(
        interests: state.interests.where((i) => i != interest).toList(),
      );
    } else {
      state = state.copyWith(interests: [...state.interests, interest]);
    }
  }

  void clearForm() {
    state = SignUpFormState();
  }
}

final signUpFormProvider =
    NotifierProvider<SignUpFormNotifier, SignUpFormState>(() {
      return SignUpFormNotifier();
    });
