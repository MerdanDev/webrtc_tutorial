import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_tutorial/firebase_interface.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

typedef SetStateCallback = void Function();

Map<String, dynamic> configuration = {
  'iceServers': [
    {
      'urls': [
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
      ],
    }
  ]
};

class Peer2PeerSignaling {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStreams;
  SetStateCallback? setState;
  bool microphoneEnabled = false;
  bool cameraEnabled = true;

  Future<void> microphoneSwitch() async {
    microphoneEnabled = !microphoneEnabled;
    localStream?.getAudioTracks().forEach((track) {
      track.enabled = microphoneEnabled;
    });
    return;
  }

  Future<void> cameraSwitch() async {
    cameraEnabled = !cameraEnabled;
    localStream?.getVideoTracks().forEach((track) {
      track.enabled = cameraEnabled;
    });
    return;
  }

  Future<String> createRoom(RTCVideoRenderer localVideo) async {
    _openUserMedia(localVideo);
    final createRoomRepository = FirebaseCallerRepository();
    createRoomRepository.createRoom();
    peerConnection = await createPeerConnection(configuration);

    registerPeerConnectionListeners();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    // Code for collecting ICE candidates below
    createRoomRepository.createCallerCollection();

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      createRoomRepository.addNewCallerCandidate(candidate);
    };
    // Finish Code for collecting ICE candidate

    // Add code for creating a room
    RTCSessionDescription offer = await peerConnection!.createOffer();
    try {
      await peerConnection!.setLocalDescription(offer);
    } catch (e) {
      debugPrint('MerdanDev room ${e.toString()}');
    }
    createRoomRepository.setNewOffer(offer);
    var roomId = createRoomRepository.getRoomId();
    currentRoomText = 'Room $roomId - Caller';
    // Created a Room

    peerConnection?.onTrack = (RTCTrackEvent event) {
      event.streams.first.getTracks().forEach((track) {
        remoteStream?.addTrack(track);
      });

      onAddRemoteStreams?.call(event.streams.first);
    };

    // Listening for remote session description below
    // gets error when room is deleted by one of the users

    createRoomRepository.onNewAnswer().listen((data) async {
      final desc = await peerConnection?.getRemoteDescription();
      if (desc == null && data['answer'] != null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        try {
          await peerConnection?.setRemoteDescription(answer);
        } catch (e) {
          debugPrint('MerdanDev room ${e.toString()}');
        }
      }
    });

    // Listening for remote session description above

    createRoomRepository.onNewCalleeCandidate().listen((data) {
      peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
    });
    // Listen for remote ICE candidates above
    debugPrint('Created new room: $roomId');
    return roomId;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer localVideo) async {
    _openUserMedia(localVideo);
    final joinRoomRepository = FirebaseCalleeRepository();
    joinRoomRepository.initRoom(roomId);
    currentRoomText = 'Room $roomId - Callee';

    final isRoomExist = await joinRoomRepository.isRoomExist();
    if (isRoomExist) {
      peerConnection = await createPeerConnection(configuration);

      registerPeerConnectionListeners();

      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });

      // Code for collecting ICE candidates below

      joinRoomRepository.createCalleeCollection();
      peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        joinRoomRepository.addNewCalleeCandidate(candidate.toMap());
      };
      // Code for collecting ICE candidate above

      peerConnection?.onTrack = (RTCTrackEvent event) {
        event.streams.first.getTracks().forEach((track) {
          remoteStream?.addTrack(track);
        });

        onAddRemoteStreams?.call(event.streams.first);
      };

      // Code for creating SDP answer below
      var data = joinRoomRepository.getOffer();

      var offer = data['offer'];
      try {
        await peerConnection?.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );
      } catch (e) {
        debugPrint('MerdanDev room $e');
      }
      var answer = await peerConnection!.createAnswer();

      await peerConnection!.setLocalDescription(answer);

      joinRoomRepository.setNewAnswer(answer);
      // Finished creating SDP answer

      joinRoomRepository.onNewCallerCandidate().listen((data) {
        peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ),
        );
      });
    }
  }

  Future<void> _openUserMedia(RTCVideoRenderer localVideo) async {
    if (localStream == null) {
      var stream = await navigator.mediaDevices.getUserMedia(
        {
          'video': cameraEnabled,
          'audio': microphoneEnabled,
        },
      );

      localVideo.srcObject = stream;
      localStream = stream;
      setState?.call();
    }
  }

  Future<void> hangUp(RTCVideoRenderer localVideo, String? roomId) async {
    List<MediaStreamTrack> tracks = localVideo.srcObject!.getTracks();
    for (var track in tracks) {
      track.stop();
    }

    remoteStream?.getTracks().forEach((track) => track.stop());
    if (peerConnection != null) peerConnection!.close();

    if (roomId != null) {
      final interface = FirebaseEndCallRepository();
      interface.hungUp(roomId);
    }

    localStream?.getTracks().forEach((track) {
      track.stop();
    });

    localStream?.dispose();
    remoteStream?.dispose();
    localStream = null;
    remoteStream = null;
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('MerdanDev room ${state.name}');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {};

    peerConnection?.onSignalingState = (RTCSignalingState state) {};

    peerConnection?.onAddStream = (MediaStream stream) {
      remoteStream = stream;

      debugPrint('MerdanDev $currentRoomText ${stream.getTracks().length}');
      onAddRemoteStreams?.call(
        remoteStream!,
      );
    };

    peerConnection?.onRemoveStream = (stream) {
      if (remoteStream?.id == stream.id) {
        remoteStream?.dispose();
        remoteStream = null;
        setState?.call();
      }
    };
  }
}
