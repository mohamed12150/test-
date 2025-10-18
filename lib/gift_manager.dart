import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

/// نموذج الهدية
class GiftModel {
  final String key;
  final String label;
  final String url;
  const GiftModel({required this.key, required this.label, required this.url});
}

/// روابط Lottie من الإنترنت (مجانية من LottieFiles)
const availableGifts = [
  GiftModel(
    key: 'giftbox1',
    label: '🎁',
    url: 'assets/gifts/Gift Box Lottie.json',
  ),


  GiftModel(
    key: 'giftbox4',
    label: '💐',
    url: 'assets/gifts/Rose Lottie.json',
  ),
  GiftModel(
    key: 'giftbox5',
    label: '🎊 بالونات',
    url: 'assets/gifts/Balloons Lottie.json',
  ),
  GiftModel(
    key: 'giftbox6',
    label: '💎 جوهرة',
    url: 'https://lottie.host/5a4f2b91-2b4b-4ce4-9313-cb37a29a0e93/v0E7gAWYVh.json',
  ),
  GiftModel(
    key: 'giftbox7',
    label: '🚗 سيارة',
    url: 'https://lottie.host/3df62944-59d7-4b64-81a1-1b1c3a29b1ab/EvN2v8CC5J.json',
  ),
  GiftModel(
    key: 'giftbox8',
    label: '💰 كوينز',
    url: 'https://lottie.host/3c896cd2-cf38-4a76-885e-5b2f345728d4/vWcJzDyYgM.json',
  ),
  GiftModel(
    key: 'giftbox9',
    label: '🎂 كيكة',
    url: 'https://lottie.host/9cd7b27c-f39c-4a0d-8d8b-0f7e36708f02/rR5tF3KvLo.json',
  ),
  GiftModel(
    key: 'giftbox10',
    label: '🕊️ طائر',
    url: 'https://lottie.host/ff43e9e4-c147-4b62-9b08-6ef8cc8e58d2/FD0iPpAEcU.json',
  ),
];


/// مدير الهدايا: مسؤول عن الإرسال، الاستقبال، والعرض
class GiftManager {
  final AnimationController controller;
  final ZegoUIKitPrebuiltLiveStreamingController liveController;
  StreamSubscription? _sub;
  String? currentUrl;
  int _lastMsgCount = 0;

  GiftManager({required this.controller, required this.liveController});

  /// استمع للرسائل القادمة من المشاركين
  void startListening(VoidCallback onGiftReceived) {
    _sub = liveController.message.stream().listen((dynamic messages) {
      try {
        final list = messages as List;
        if (list.length > _lastMsgCount) {
          for (var i = _lastMsgCount; i < list.length; i++) {
            final msg = list[i];
            final content = msg.message;
            if (content is String && content.startsWith('GIFT:')) {
              final key = content.substring(5);
              final gift = availableGifts.firstWhere(
                (g) => g.key == key,
                orElse: () => availableGifts.first,
              );
              playGift(gift);
              onGiftReceived();
            }
          }
          _lastMsgCount = list.length;
        }
      } catch (_) {}
    });
  }

  void dispose() => _sub?.cancel();

  /// إرسال الهدية للجميع
  Future<void> broadcastGift(GiftModel gift) async {
    playGift(gift);
    try {
      await liveController.message.send('GIFT:${gift.key}');
    } catch (_) {}
  }

  /// تشغيل الهدية محليًا
  void playGift(GiftModel gift) {
    currentUrl = gift.url;
  }
}

/// عرض الهدية الحالية
class GiftDisplay extends StatelessWidget {
  final GiftManager manager;
  const GiftDisplay({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    if (manager.currentUrl == null) return const SizedBox.shrink();

    return Center(
      child: Lottie.asset(
       manager.currentUrl!,
        controller: manager.controller,
        repeat: false,
        onLoaded: (composition) {
          manager.controller
            ..duration = composition.duration
            ..forward(from: 0);
        },
        errorBuilder: (context, error, stack) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'تعذر تحميل الهدية من الإنترنت',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// شريط الهدايا السفلي
class GiftChipBar extends StatelessWidget {
  final GiftManager manager;
  const GiftChipBar({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableGifts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final gift = availableGifts[i];
          return GestureDetector(
            onTap: () => manager.broadcastGift(gift),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(child: Text(gift.label)),
            ),
          );
        },
      ),
    );
  }
}
