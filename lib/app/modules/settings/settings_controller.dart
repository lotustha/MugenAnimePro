import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/remote_settings_service.dart';

class SettingsController extends GetxController {
  final RemoteSettingsService settings = Get.find();

  /// Open [url] in the external browser/app. Shows a hint if it isn't set.
  Future<void> open(String url) async {
    if (url.isEmpty) {
      Get.snackbar('Unavailable', 'This link isn\'t available yet.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar('Couldn\'t open', url);
    }
  }
}
