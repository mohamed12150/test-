import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'gift_manager.dart';
import 'zego_config.dart'; // ملف إعدادات Zego لديك

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'البث المباشر',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const LiveStartPage(),
    );
  }
}

enum LiveRole { host, audience }

class LiveStartPage extends StatefulWidget {
  const LiveStartPage({super.key});

  @override
  State<LiveStartPage> createState() => _LiveStartPageState();
}

class _LiveStartPageState extends State<LiveStartPage> {
  final _roomCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  LiveRole _role = LiveRole.host;

  @override
  void dispose() {
    _roomCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  void _goToSession() {
    final roomId = _roomCtrl.text.trim();
    final userId = _userCtrl.text.trim();
    if (roomId.isEmpty || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال معرف الغرفة ومعرف المستخدم')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveSessionPage(roomId: roomId, userId: userId, role: _role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('البث المباشر')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: 'معرّف الغرفة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'معرّف المستخدم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<LiveRole>(
              segments: const [
                ButtonSegment(value: LiveRole.host, icon: Icon(Icons.videocam), label: Text('المضيف')),
                ButtonSegment(value: LiveRole.audience, icon: Icon(Icons.visibility), label: Text('المشاهد')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: Icon(_role == LiveRole.host ? Icons.radio : Icons.login),
                onPressed: _goToSession,
                label: Text(_role == LiveRole.host ? 'ابدأ البث' : 'انضم للبث'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class LiveSessionPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final LiveRole role;

  const LiveSessionPage({super.key, required this.roomId, required this.userId, required this.role});

  @override
  State<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends State<LiveSessionPage> with SingleTickerProviderStateMixin {
  late final bool isHost;
  late final AnimationController _giftController;
  late final ZegoUIKitPrebuiltLiveStreamingController _liveController;
  late final GiftManager _giftManager;

  @override
  void initState() {
    super.initState();
    isHost = widget.role == LiveRole.host;
    _liveController = ZegoUIKitPrebuiltLiveStreamingController();
    _giftController = AnimationController(vsync: this);
    _giftManager = GiftManager(controller: _giftController, liveController: _liveController);

    _giftManager.startListening(() => setState(() {}));

    _giftController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _giftManager.currentUrl = null);
        _giftController.reset();
      }
    });
  }

  @override
  void dispose() {
    _giftManager.dispose();
    _giftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveConfig = isHost
        ? ZegoUIKitPrebuiltLiveStreamingConfig.host()
        : ZegoUIKitPrebuiltLiveStreamingConfig.audience();

    liveConfig.video = ZegoUIKitVideoConfig.preset540P()..fps = 24;
    liveConfig.turnOnCameraWhenJoining = isHost;
    liveConfig.turnOnMicrophoneWhenJoining = isHost;
    liveConfig.useSpeakerWhenJoining = true;

    return Scaffold(
      appBar: AppBar(title: Text(isHost ? 'معاينة البث' : 'مشاهدة البث')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ZegoUIKitPrebuiltLiveStreaming(
                      appID: zegoAppID,
                      appSign: zegoAppSign,
                      userID: widget.userId,
                      userName: 'user_${widget.userId}',
                      liveID: widget.roomId,
                      config: liveConfig,
                    ),
                    GiftDisplay(manager: _giftManager),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GiftChipBar(manager: _giftManager),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    label: const Text('رجوع'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(isHost ? Icons.wifi_tethering : Icons.play_arrow),
                    onPressed: () {},
                    label: Text(isHost ? 'بدء البث' : 'بدء المشاهدة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
