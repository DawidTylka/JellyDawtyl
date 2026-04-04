import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/storage_service.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _adsEnabled = false;
  bool _isCheckingPreference = true;

  final String _adUnitId = Platform.isAndroid
      ? (dotenv.env['ADMOB_BANNER_ANDROID'] ??
            'ca-app-pub-3940256099942544/6300978111')
      : (dotenv.env['ADMOB_BANNER_IOS'] ??
            'ca-app-pub-3940256099942544/2934735716');

  @override
  void initState() {
    super.initState();
    _checkPreferenceAndLoadAd();
  }

  Future<void> _checkPreferenceAndLoadAd() async {
    final storage = StorageService();
    final choice = await storage.getString('setting_ads_choice');

    if (!mounted) return;

    if (choice == 'yes') {
      setState(() {
        _adsEnabled = true;
        _isCheckingPreference = false;
      });
      _loadAd();
    } else {
      setState(() {
        _adsEnabled = false;
        _isCheckingPreference = false;
      });
    }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad załadowana pomyślnie.');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Błąd ładowania reklamy: ${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPreference ||
        !_adsEnabled ||
        !_isLoaded ||
        _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
