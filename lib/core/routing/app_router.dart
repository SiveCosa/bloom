import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Shell and Auth Providers
import '../../domain/auth/auth_providers.dart';
// import '../../ui/main_shell/shell_screen.dart'; // Uncomment when ShellScreen is ready

// Import Login UI screens
import '../../ui/auth/login/email_screen.dart' as login;
import '../../ui/auth/login/otp_screen.dart' as login_otp;
import '../../ui/auth/login/confirm_screen.dart' as login_confirm;

// Import Sign-Up UI screens
import '../../ui/auth/signup/email_screen.dart' as signup;
import '../../ui/auth/signup/otp_screen.dart' as signup_otp;
import '../../ui/auth/signup/details_screen.dart';
import '../../ui/auth/signup/campus_screen.dart';
import '../../ui/auth/signup/avatar_screen.dart';
import '../../ui/auth/signup/interests_screen.dart';
import '../../ui/auth/signup/permissions_screen.dart';
import '../../ui/main_shell/main_shell.dart';
import '../../ui/profile/sub_screens/friends_made_screen.dart';
import '../../ui/profile/sub_screens/events_hosted_screen.dart';
import '../../ui/profile/sub_screens/events_joined_screen.dart';
import '../../ui/profile/sub_screens/interested_events_screen.dart';
import '../../ui/profile/sub_screens/preferences_editor_screen.dart';
import '../../ui/profile/sub_screens/edit_profile_screen.dart';
import '../../ui/create_event/create_event_screen.dart';
import '../../ui/create_event/event_preview_screen.dart';
import '../../ui/event/event_invitation_screen.dart';
import '../../ui/messages/messages_screen.dart';
import '../../ui/notifications/notifications_screen.dart';
// import '../../ui/auth/signup/loading_screen.dart'; // Keep if using a separate loading sequence

// No longer using PlaceholderScreen

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Re-evaluates [GoRouter.redirect] when auth changes **without** disposing
/// [GoRouter]. Watching [authStateChangesProvider] on the router provider
/// recreates [GoRouter] and resets to [initialLocation], which sent sign-up
/// users to `/` right after OTP verification.
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(FirebaseAuth auth) {
    _sub = auth.authStateChanges().listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Path only, no query; trailing slash removed for stable whitelist matching.
String _normalizedAuthPath(GoRouterState state) {
  var path = state.uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  final refresh = _AuthRouterRefresh(auth);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isAuth = auth.currentUser != null;
      final path = _normalizedAuthPath(state);
      final isAuthRoute = path.startsWith('/auth');

      // 1. If NOT logged in, and trying to access the main app, kick to login
      if (!isAuth && !isAuthRoute) {
        return '/auth/login';
      }

      // 2. If LOGGED IN, and trying to access auth screens
      if (isAuth && isAuthRoute) {
        // Whitelist paths an authenticated user may use while finishing login/sign-up.
        const allowedAuthRoutes = <String>{
          '/auth/signup/otp',
          '/auth/login/otp',
          '/auth/signup/details',
          '/auth/signup/campus',
          '/auth/signup/avatar',
          '/auth/signup/interests',
          '/auth/signup/permissions',
          '/auth/signup/loading',
          '/auth/login/confirm',
        };

        if (allowedAuthRoutes.contains(path)) {
          return null;
        }

        return '/';
      }

      return null;
    },
    routes: [
      // ==========================
      // AUTH FLOWS
      // ==========================
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const login.EmailScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (context, state) => const login_otp.OtpScreen(),
          ),
          GoRoute(
            path: 'confirm',
            builder: (context, state) => const login_confirm.ConfirmScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const signup.EmailScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (context, state) => const signup_otp.OtpScreen(),
          ),
          GoRoute(
            path: 'details',
            builder: (context, state) => const DetailsScreen(),
          ),
          GoRoute(
            path: 'campus',
            builder: (context, state) => const CampusScreen(),
          ),
          GoRoute(
            path: 'avatar',
            builder: (context, state) => const AvatarScreen(),
          ),
          GoRoute(
            path: 'interests',
            builder: (context, state) => const InterestsScreen(),
          ),
          GoRoute(
            path: 'permissions',
            builder: (context, state) => const PermissionsScreen(),
          ),
          // GoRoute(
          //   path: 'loading',
          //   builder: (context, state) => const LoadingScreen(),
          // ),
        ],
      ),

      // ==========================
      // MAIN APP SHELL
      // ==========================
      GoRoute(path: '/', builder: (context, state) => const MainShell()),
      GoRoute(
        path: '/profile/friends',
        builder: (context, state) => const FriendsMadeScreen(),
      ),
      GoRoute(
        path: '/profile/hosted',
        builder: (context, state) => const EventsHostedScreen(),
      ),
      GoRoute(
        path: '/profile/joined',
        builder: (context, state) => const EventsJoinedScreen(),
      ),
      GoRoute(
        path: '/profile/interested',
        builder: (context, state) => const InterestedEventsScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/preferences',
        builder: (context, state) => const PreferencesEditorScreen(),
      ),
      GoRoute(
        path: '/create-event',
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/create-event/preview',
        builder: (context, state) => const EventPreviewScreen(),
      ),
      GoRoute(
        path: '/event/:eventId',
        pageBuilder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: EventInvitationScreen(eventId: eventId),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return child;
            },
          );
        },
      ),
      GoRoute(
        path: '/messages',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MessagesScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationsScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
        ),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
