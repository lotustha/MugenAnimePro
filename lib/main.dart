import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit/media_kit.dart';

import 'app/core/bindings/initial_binding.dart';
import 'app/core/theme/app_theme.dart';
import 'app/data/services/ads_service.dart';
import 'app/data/services/inapp_message_service.dart';
import 'app/data/services/notification_service.dart';
import 'app/data/services/push_service.dart';
import 'app/data/services/remote_settings_service.dart';
import 'app/data/services/storage_service.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv / native player setup (required before any Player() is created).
  MediaKit.ensureInitialized();

  // Local persistence.
  await GetStorage.init();

  // Firebase + FCM background handler must be registered before runApp.
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {
    // No google-services.json / Play Services — app runs without push.
  }

  // Storage must be ready before the first frame (Home/Library/Detail read it).
  await Get.putAsync<StorageService>(() => StorageService().init());
  // Needed by the first post-frame work (reminders + remote config). Run them
  // concurrently instead of one-after-another.
  await Future.wait([
    Get.putAsync<NotificationService>(() => NotificationService().init()),
    Get.putAsync<RemoteSettingsService>(() => RemoteSettingsService().init()),
  ]);
  // Push + in-app messaging do a permission prompt and network round-trips that
  // must NOT gate first paint. Register them now (so Get.find works) and run
  // their init() once the UI is on screen.
  Get.put<PushService>(PushService(), permanent: true);
  Get.put<InAppMessageService>(InAppMessageService(), permanent: true);
  // Ads SDK init (MobileAds.initialize) is also off the first-paint path.
  Get.put<AdsService>(AdsService(), permanent: true);

  runApp(const AnimeStreamApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Start the ads SDK + preload first and concurrently — it must NOT wait on
    // push (permission prompt + FCM network), or a rewarded ad won't be ready
    // when the user reaches it.
    Get.find<AdsService>().init();
    await Get.find<PushService>().init();
    Get.find<PushService>().flushInitialMessage();
    await Get.find<InAppMessageService>().init();
    Get.find<InAppMessageService>().maybeShowOnLaunch();
  });
}

class AnimeStreamApp extends StatelessWidget {
  const AnimeStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Mugen Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialBinding: InitialBinding(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
