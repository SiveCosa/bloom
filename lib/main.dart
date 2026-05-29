import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'data/firebase_provider.dart';
import 'domain/chat/cometchat_session_provider.dart';

class CustomEnShortMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => '';
  @override
  String suffixFromNow() => '';
  @override
  String lessThanOneMinute(int seconds) => 'now';
  @override
  String aboutAMinute(int minutes) => '1m';
  @override
  String minutes(int minutes) => '${minutes}m';
  @override
  String aboutAnHour(int minutes) => '1h';
  @override
  String hours(int hours) => '${hours}h';
  @override
  String aDay(int hours) => '1d';
  @override
  String days(int days) => '${days}d';
  @override
  String aboutAMonth(int days) => '1mo';
  @override
  String months(int months) => '${months}mo';
  @override
  String aboutAYear(int years) => '1y';
  @override
  String years(int years) => '${years}y';
  @override
  String wordSeparator() => ' ';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timeago.setLocaleMessages('en_short', CustomEnShortMessages());

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Firebase & AppCheck
  await FirebaseProvider.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Establish CometChat session when Firebase user is signed in.
    ref.watch(cometChatSessionProvider);

    return MaterialApp.router(
      title: 'Bloom', // Confirmed project name
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode:
          ThemeMode.dark, // Defaulting to dark mode as per your UI/UX focus
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(overscroll: false, physics: const ClampingScrollPhysics()),
          child: child!,
        );
      },
    );
  }
}
