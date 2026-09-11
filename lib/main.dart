import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/feature_flags.dart';
import 'core/utils/maps_loader.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/utils/firebase_options.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/payment_service.dart';
import 'core/services/notification_coordinator.dart';
import 'features/auth/presentation/widgets/email_verification_banner.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) print('🔔 Background FCM message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    const recaptchaSiteKey = String.fromEnvironment(
      'RECAPTCHA_SITE_KEY',
      defaultValue: '',
    );
    await FirebaseAppCheck.instance.activate(
      webProvider: recaptchaSiteKey.isNotEmpty
          ? ReCaptchaV3Provider(recaptchaSiteKey)
          : null,
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      appleProvider: kReleaseMode
          ? AppleProvider.deviceCheck
          : AppleProvider.debug,
    );
  } catch (e) {
    if (kDebugMode) print('⚠️ App Check activation failed: $e');
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  if (kIsWeb) {
    const mapsKey = String.fromEnvironment('MAPS_API_KEY');
    if (mapsKey.isNotEmpty) await loadGoogleMapsScript(mapsKey);
  }

  if (!kIsWeb) {
    try {
      await NotificationCoordinator.instance.initialize();
    } catch (e) {
      if (kDebugMode) print('Error initializing notification coordinator: $e');
    }
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(
      themeModeProvider,
      (previous, next) => _updateSystemUiOverlayStyle(next),
      fireImmediately: true,
    );

    if (!kIsWeb) {
      const stripeKey = String.fromEnvironment(
        'STRIPE_PUBLISHABLE_KEY',
        defaultValue: '',
      );
      if (stripeKey.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          PaymentService.initialize(publishableKey: stripeKey);
        });
      } else if (kDebugMode) {
        print('⚠️ STRIPE_PUBLISHABLE_KEY not set — skipping Stripe init');
      }
    }
  }

  void _updateSystemUiOverlayStyle(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: isDarkMode
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        systemNavigationBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isDarkMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('he')],
      locale: const Locale('he'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            children: [
              FeatureFlags.demoMode
                  ? Banner(
                      message: 'DEMO',
                      location: BannerLocation.topStart,
                      child: child!,
                    )
                  : child!,
              const SafeArea(child: EmailVerificationBanner()),
            ],
          ),
        );
      },
    );
  }
}
