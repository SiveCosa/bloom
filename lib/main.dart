import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import for environment variables
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'data/firebase_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the environment variables from your .env file
  await dotenv.load(fileName: ".env");

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
