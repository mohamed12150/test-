import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart' as arch;

import 'zego_config.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
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
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  LiveRole _role = LiveRole.host;

  @override
  void dispose() {
    _roomIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  void _goToSession() {
    final roomId = _roomIdController.text.trim();
    final userId = _userIdController.text.trim();
    if (roomId.isEmpty || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال معرف الغرفة ومعرف المستخدم')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveSessionPage(
          roomId: roomId,
          userId: userId,
          role: _role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البث المباشر'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _roomIdController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'معرّف الغرفة (Room ID)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userIdController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'معرّف المستخدم (User ID)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<LiveRole>(
                segments: const [
                  ButtonSegment(
                    value: LiveRole.host,
                    icon: Icon(Icons.videocam),
                    label: Text('المضيف'),
                  ),
                  ButtonSegment(
                    value: LiveRole.audience,
                    icon: Icon(Icons.visibility),
                    label: Text('المشاهد'),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (set) {
                  setState(() => _role = set.first);
                },
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  icon: Icon(_role == LiveRole.host ? Icons.radio_button_checked : Icons.login),
                  onPressed: _goToSession,
                  label: Text(_role == LiveRole.host ? 'ابدأ البث' : 'انضم للبث'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveSessionPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final LiveRole role;

  const LiveSessionPage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.role,
  });

  @override
  State<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends State<LiveSessionPage>
    with SingleTickerProviderStateMixin {
  late final bool isHost;
  AnimationController? _giftController;
  String? _giftAsset;
  final _liveController = ZegoUIKitPrebuiltLiveStreamingController();
  StreamSubscription? _msgSub;
  int _lastMsgCount = 0;
  Future<Uint8List>? _giftBytesFuture;
  final Map<String, Future<Uint8List>> _giftBytesCache = {};

  @override
  void initState() {
    super.initState();
    isHost = widget.role == LiveRole.host;
    _giftController = AnimationController(vsync: this);
    _giftController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _giftAsset = null);
        _giftController!.reset();
      }
    });

    // Listen for in-room messages to sync gifts between users
    _msgSub = _liveController.message
        .stream()
        .listen((dynamic messages) {
      try {
        final List list = messages as List;
        if (list.length > _lastMsgCount) {
          for (var i = _lastMsgCount; i < list.length; i++) {
            final m = list[i];
            final content = m.message;
            if (content is String && content.startsWith('GIFT:')) {
              final key = content.substring(5);
              final asset = _assetForGiftKey(key);
              if (asset != null) {
                _sendGift(asset);
              }
            }
          }
          _lastMsgCount = list.length;
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _giftController?.dispose();
    _msgSub?.cancel();
    super.dispose();
  }

  void _sendGift(String assetPath) {
    setState(() {
      _giftAsset = assetPath;
      _giftBytesFuture = _giftBytesCache[assetPath] ??=
          _prepareLottieBytesFromBundle(assetPath);
    });
  }

  String? _assetForGiftKey(String key) {
    switch (key) {
      case 'rose':
        return 'assets/gifts/rose gift.lottie';
      case 'money':
        return 'assets/gifts/Money rain.lottie';
      case 'confetti':
        return 'assets/gifts/Confetti Day.lottie';
    }
    return null;
  }

  Future<void> _broadcastGift(String key, String asset) async {
    _sendGift(asset);
    // Broadcast to all participants
    try {
      await _liveController.message.send('GIFT:$key');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAppSign = zegoAppSign.isNotEmpty && !zegoAppSign.startsWith('REPLACE_');

    final liveConfig = isHost
        ? ZegoUIKitPrebuiltLiveStreamingConfig.host()
        : ZegoUIKitPrebuiltLiveStreamingConfig.audience();
    // تخفيف الحمل على الجهاز عبر دقة وفريم أقل
    liveConfig.video = ZegoUIKitVideoConfig.preset540P()..fps = 24;
    liveConfig.turnOnCameraWhenJoining = isHost;
    liveConfig.turnOnMicrophoneWhenJoining = isHost;
    liveConfig.useSpeakerWhenJoining = true;

    Widget liveView = hasAppSign
        ? ZegoUIKitPrebuiltLiveStreaming(
            appID: zegoAppID,
            appSign: zegoAppSign,
            userID: widget.userId,
            userName: 'user_${widget.userId}',
            liveID: widget.roomId,
            config: liveConfig,
          )
          : DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black12),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.live_tv, size: 64, color: Colors.black45),
                    const SizedBox(height: 12),
                    const Text('لم يتم إعداد AppSign بعد.'),
                    const SizedBox(height: 8),
                    const Text('ضع قيمة AppSign في lib/zego_config.dart للمتابعة.'),
                    const SizedBox(height: 8),
                    Text('Room: ${widget.roomId}  •  User: ${widget.userId}'),
                  ],
                ),
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(isHost ? 'معاينة البث' : 'مشاهدة البث'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      liveView,
                      if (_giftAsset != null)
                        Center(
                          child: FutureBuilder<Uint8List>(
                            future: _giftBytesFuture,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return LottieBuilder.memory(
                                snapshot.data!,
                                controller: _giftController,
                                onLoaded: (composition) {
                                  _giftController!
                                    ..duration = composition.duration
                                    ..forward(from: 0);
                                },
                                fit: BoxFit.contain,
                                backgroundLoading: true,
                                errorBuilder: (context, error, stack) {
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'تعذر تشغيل الهدية',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // شريط الهدايا
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _GiftChip(
                      label: '🌹 وردة',
                      onTap: () => _broadcastGift('rose', 'assets/gifts/rose gift.lottie'),
                    ),
                    const SizedBox(width: 8),
                    _GiftChip(
                      label: '💸 مطر فلوس',
                      onTap: () => _broadcastGift('money', 'assets/gifts/Money rain.lottie'),
                    ),
                    const SizedBox(width: 8),
                    _GiftChip(
                      label: '🎉 كونفيتي',
                      onTap: () => _broadcastGift('confetti', 'assets/gifts/Confetti Day.lottie'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
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
      ),
    );
  }
}

class _GiftChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GiftChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(child: Text(label)),
      ),
    );
  }
}

Future<Uint8List> _prepareLottieBytesFromBundle(String assetPath) async {
  // 1) حاول القراءة كنص JSON مباشرة
  try {
    final jsonStr = await rootBundle.loadString(assetPath);
    return _fixLottieJsonBytes(jsonStr);
  } catch (_) {
    // ليس JSON نصي (ربما .lottie zip)
  }

  // 2) اقرأ كبايتات: إن كان Zip (.lottie) استخرج ملف JSON وعدّله
  try {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      // 'PK' header => zip (.lottie). أعِد بناء الأرشيف مع JSON مُصحّح، وأبقِ الصور كما هي.
      final inArchive = arch.ZipDecoder().decodeBytes(bytes, verify: false);
      final outArchive = arch.Archive();

      for (final file in inArchive.files) {
        if (file.isFile && file.name.toLowerCase().endsWith('.json')) {
          try {
            final jsonStr = utf8.decode(file.content as List<int>);
            final fixed = _fixLottieJsonBytes(jsonStr);
            outArchive.addFile(arch.ArchiveFile(file.name, fixed.length, fixed)
              ..mode = file.mode
              ..lastModTime = file.lastModTime
              ..compress = file.compress);
          } catch (_) {
            final orig = Uint8List.fromList(file.content as List<int>);
            outArchive.addFile(arch.ArchiveFile(file.name, orig.length, orig)
              ..mode = file.mode
              ..lastModTime = file.lastModTime
              ..compress = file.compress);
          }
        } else {
          // انسخ باقي الملفات كما هي (صور، خطوط، مجلدات)
          final content = file.content is List<int>
              ? Uint8List.fromList(file.content as List<int>)
              : (file.content as Uint8List? ?? Uint8List(0));
          outArchive.addFile(arch.ArchiveFile(file.name, content.length, content)
            ..mode = file.mode
            ..lastModTime = file.lastModTime
            ..compress = file.compress
            ..unixPermissions = file.unixPermissions);
        }
      }

      final outBytes = arch.ZipEncoder().encode(outArchive) ?? <int>[];
      return Uint8List.fromList(outBytes);
    }
    // إذا لم يكن zip نعيد المحتوى كما هو
    return bytes;
  } catch (_) {
    // كحل أخير، أعد البايتات الخام
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }
}

Uint8List _fixLottieJsonBytes(String jsonStr) {
  try {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      double ip = 0.0;
      final ipRaw = decoded['ip'];
      if (ipRaw is num) ip = ipRaw.toDouble();
      if (ipRaw is String) ip = double.tryParse(ipRaw) ?? 0.0;

      double fr = 30.0;
      final frRaw = decoded['fr'];
      if (frRaw is num) fr = frRaw.toDouble();
      if (frRaw is String) fr = double.tryParse(frRaw) ?? 30.0;
      if (fr <= 0) fr = 30.0;

      double op = ip;
      final opRaw = decoded['op'];
      if (opRaw is num) op = opRaw.toDouble();
      if (opRaw is String) op = double.tryParse(opRaw) ?? ip;

      // تأكد أن startFrame != endFrame وأن هناك مدة فعلية
      if ((op - 0.01) <= ip) {
        decoded['ip'] = ip; // اجعل البداية كما هي
        decoded['op'] = ip + fr + 1.0; // مدة آمنة > 1 ثانية
      }

      final out = jsonEncode(decoded);
      return Uint8List.fromList(utf8.encode(out));
    }
  } catch (_) {
    // تجاهل الخطأ وارجع النص الأصلي
  }
  return Uint8List.fromList(utf8.encode(jsonStr));
}
