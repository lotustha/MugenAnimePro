import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/services/ads_service.dart';

/// A full-width in-feed native ad (AdMob medium template). Renders nothing
/// until an ad loads, and nothing at all when ads are disabled or the active
/// provider has no native format — so it's safe to drop into any feed.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!Get.isRegistered<AdsService>()) return;
    final ads = Get.find<AdsService>();
    if (!ads.nativeEnabled) return;
    _ad = NativeAd(
      adUnitId: ads.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.medium),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      height: 330,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: AdWidget(ad: _ad!),
    );
  }
}
