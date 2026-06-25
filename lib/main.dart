import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit/media_kit.dart';

import 'app/core/bindings/initial_binding.dart';
import 'app/core/theme/app_theme.dart';
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

  await Get.putAsync<StorageService>(() => StorageService().init());
  await Get.putAsync<NotificationService>(() => NotificationService().init());
  await Get.putAsync<RemoteSettingsService>(() => RemoteSettingsService().init());
  await Get.putAsync<PushService>(() => PushService().init());
  await Get.putAsync<InAppMessageService>(() => InAppMessageService().init());

  runApp(const AnimeStreamApp());
}

class AnimeStreamApp extends StatelessWidget {
  const AnimeStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'AnimeStream',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialBinding: InitialBinding(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
