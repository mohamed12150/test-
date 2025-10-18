import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:zego_uikit/zego_uikit.dart';

import 'zego_config.dart';

enum VoiceRole { host, audience }

class VoiceRoomStartPage extends StatefulWidget {
  const VoiceRoomStartPage({super.key});

  @override
  State<VoiceRoomStartPage> createState() => _VoiceRoomStartPageState();
}

class _VoiceRoomStartPageState extends State<VoiceRoomStartPage> {
  final _roomCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  VoiceRole _role = VoiceRole.host;

  @override
  void dispose() {
    _roomCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  void _goToVoiceRoom() {
    final roomId = _roomCtrl.text.trim();
    final userId = _userCtrl.text.trim();
    if (roomId.isEmpty || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter room ID and user ID.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceRoomPage(
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
      appBar: AppBar(title: const Text('Voice Room')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<VoiceRole>(
              segments: const [
                ButtonSegment(value: VoiceRole.host, icon: Icon(Icons.mic), label: Text('Host')),
                ButtonSegment(value: VoiceRole.audience, icon: Icon(Icons.headset), label: Text('Audience')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.meeting_room),
                onPressed: _goToVoiceRoom,
                label: const Text('Enter Voice Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceRoomPage extends StatelessWidget {
  final String roomId;
  final String userId;
  final VoiceRole role;

  const VoiceRoomPage({super.key, required this.roomId, required this.userId, required this.role});

  @override
  Widget build(BuildContext context) {
    final isHost = role == VoiceRole.host;

    final config = (isHost
            ? ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
            : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience())
          ..turnOnMicrophoneWhenJoining = isHost
          ..useSpeakerWhenJoining = true
          ..seat = (ZegoLiveAudioRoomSeatConfig()
            ..takeIndexWhenJoining = isHost ? 0 : -1
            ..hostIndexes = const [0])
          ..topMenuBar.buttons = const [
            ZegoLiveAudioRoomMenuBarButtonName.minimizingButton,
            ZegoLiveAudioRoomMenuBarButtonName.leaveButton,
          ]
          ..bottomMenuBar = ZegoLiveAudioRoomBottomMenuBarConfig(
            hostButtons: const [
              ZegoLiveAudioRoomMenuBarButtonName.soundEffectButton,
              ZegoLiveAudioRoomMenuBarButtonName.toggleMicrophoneButton,
              ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
              ZegoLiveAudioRoomMenuBarButtonName.closeSeatButton,
            ],
            speakerButtons: const [
              ZegoLiveAudioRoomMenuBarButtonName.soundEffectButton,
              ZegoLiveAudioRoomMenuBarButtonName.toggleMicrophoneButton,
              ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
            ],
            audienceButtons: const [
              ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
              ZegoLiveAudioRoomMenuBarButtonName.applyToTakeSeatButton,
            ],
            hostExtendButtons: [
              _AudioRouteButton(localUserId: userId),
            ],
            speakerExtendButtons: [
              _AudioRouteButton(localUserId: userId),
            ],
            audienceExtendButtons: [
              _AudioRouteButton(localUserId: userId),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: Text(isHost ? 'Voice Room (Host)' : 'Voice Room (Audience)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ZegoUIKitPrebuiltLiveAudioRoom(
            appID: zegoAppID,
            appSign: zegoAppSign,
            userID: userId,
            userName: 'user_$userId',
            roomID: roomId,
            config: config,
          ),
        ),
      ),
    );
  }
}

class _AudioRouteButton extends StatelessWidget {
  final String localUserId;
  const _AudioRouteButton({required this.localUserId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZegoUIKitAudioRoute>(
      valueListenable: ZegoUIKit().getAudioOutputDeviceNotifier(localUserId),
      builder: (context, route, _) {
        final isSpeaker = route == ZegoUIKitAudioRoute.speaker;
        return IconButton(
          tooltip: isSpeaker ? 'Speaker' : 'Earpiece/Headset',
          icon: Icon(isSpeaker ? Icons.volume_up : Icons.hearing),
          onPressed: () {
            ZegoUIKit().setAudioOutputToSpeaker(!isSpeaker);
          },
        );
      },
    );
  }
}
