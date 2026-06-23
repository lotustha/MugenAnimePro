import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../providers/anilist_client.dart';
import 'storage_service.dart';

/// Schedules local "new episode" reminders for anime the user follows.
///
/// Reminders fire at the AniList airing time. They survive the app being
/// killed (AlarmManager) but not a reboot, so [rescheduleAll] re-arms them on
/// every launch — which also rolls each reminder forward to the next episode
/// once the previous one has aired.
class NotificationService extends GetxService {
  static const _channelId = 'episodes';
  static const _channelName = 'Episode reminders';
  static const _channelDesc = 'Alerts when a new episode of a followed anime airs';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// While true (i.e. the user is watching), no reminder is shown or scheduled
  /// so nothing pops over the video.
  bool _suppressed = false;

  Future<NotificationService> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Leave the default (UTC) if the platform timezone can't be resolved.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );

    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    ));
    _ready = true;
    return this;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Request the OS notification permission (Android 13+). Returns true if
  /// granted, or on older versions where no runtime prompt exists.
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  /// Stable, positive notification id derived from the anime id.
  int _idFor(String animeId) => animeId.hashCode & 0x7fffffff;

  /// Schedule (replacing any existing) a reminder for [title] episode
  /// [episode] at [airAt]. No-op if the time is already in the past.
  Future<void> scheduleEpisode({
    required String animeId,
    required String title,
    required int episode,
    required DateTime airAt,
  }) async {
    if (!_ready || _suppressed) return;
    final when = tz.TZDateTime.from(airAt, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: _idFor(animeId),
      title: title,
      body: 'Episode $episode is out now',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(String animeId) => _plugin.cancel(id: _idFor(animeId));

  /// Silence reminders while the user is watching: clears any pending (and
  /// displayed) notifications and blocks new ones until [resume] is called.
  Future<void> suppress() async {
    _suppressed = true;
    if (_ready) await _plugin.cancelAll();
  }

  /// Re-enable reminders after watching and re-arm them with fresh times.
  Future<void> resume() async {
    _suppressed = false;
    await rescheduleAll();
  }

  /// Re-arm reminders for every followed anime using fresh AniList airing
  /// times. Called on launch so reminders roll to the next episode.
  Future<void> rescheduleAll() async {
    if (!_ready) return;
    final storage = Get.find<StorageService>();
    final aniList = Get.find<AniListClient>();
    for (final entry in storage.notifyAnime.entries) {
      final malId = int.tryParse(entry.value['malId'] ?? '');
      if (malId == null) continue;
      final next = await aniList.nextAiring(malId);
      if (next == null) continue;
      await scheduleEpisode(
        animeId: entry.key,
        title: entry.value['title']?.isNotEmpty == true
            ? entry.value['title']!
            : 'New episode',
        episode: next.episode,
        airAt: next.airingAt,
      );
    }
  }
}
