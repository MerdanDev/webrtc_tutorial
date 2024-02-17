import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FirebaseCallerRepository extends CallerInterface {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  late final DocumentReference roomRef;
  late final CollectionReference callerCandidatesCollection;
  final StreamController<Map<String, dynamic>> offerStreamController =
      StreamController();
  final StreamController<Map<String, dynamic>> calleeStreamController =
      StreamController();

  @override
  void createRoom() {
    roomRef = db.collection('rooms').doc();

    roomRef.snapshots().listen((snapshot) async {
      final snapshotData = snapshot.data();
      if (snapshotData is Map<String, dynamic>) {
        Map<String, dynamic> data = snapshotData;
        offerStreamController.add(data);
      } else {}
    });
  }

  @override
  void createCallerCollection() {
    callerCandidatesCollection = roomRef.collection('callerCandidates');
    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          calleeStreamController.add(data);
        }
      }
    });
  }

  @override
  void addNewCallerCandidate(RTCIceCandidate candidate) {
    callerCandidatesCollection.add(candidate.toMap());
  }

  @override
  void setNewOffer(RTCSessionDescription offer) {
    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};

    roomRef.set(roomWithOffer);
  }

  @override
  Stream<Map<String, dynamic>> onNewAnswer() => offerStreamController.stream;

  @override
  Stream<Map<String, dynamic>> onNewCalleeCandidate() =>
      calleeStreamController.stream;

  @override
  String getRoomId() {
    return roomRef.id;
  }
}

class FirebaseCalleeRepository extends CalleeInterface {
  FirebaseFirestore db = FirebaseFirestore.instance;
  late DocumentReference roomRef;
  late CollectionReference calleeCandidatesCollection;
  late DocumentSnapshot<Object?> roomSnapshot;
  final StreamController<Map<String, dynamic>> callerStreamController =
      StreamController();

  @override
  void initRoom(String roomId) {
    roomRef = db.collection('rooms').doc(roomId);
  }

  @override
  Future<bool> isRoomExist() async {
    roomSnapshot = await roomRef.get();
    return roomSnapshot.exists;
  }

  @override
  void createCalleeCollection() {
    calleeCandidatesCollection = roomRef.collection('calleeCandidates');
    roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
      for (var document in snapshot.docChanges) {
        var data = document.doc.data() as Map<String, dynamic>;
        callerStreamController.add(data);
      }
    });
  }

  @override
  void addNewCalleeCandidate(RTCIceCandidate candidate) {
    calleeCandidatesCollection.add(candidate.toMap());
  }

  @override
  Map<String, dynamic> getOffer() {
    var data = roomSnapshot.data() as Map<String, dynamic>;
    return data;
  }

  @override
  void setNewAnswer(RTCSessionDescription answer) {
    Map<String, dynamic> roomWithAnswer = {
      'answer': {'type': answer.type, 'sdp': answer.sdp}
    };

    roomRef.set(roomWithAnswer);
  }

  @override
  Stream<Map<String, dynamic>> onNewCallerCandidate() =>
      callerStreamController.stream;
}

class FirebaseEndCallRepository extends EndCallInterface {
  @override
  Future<void> hungUp(String roomId) async {
    var db = FirebaseFirestore.instance;
    var roomRef = db.collection('rooms').doc(roomId);
    var calleeCandidates = await roomRef.collection('calleeCandidates').get();
    for (var document in calleeCandidates.docs) {
      document.reference.delete();
    }

    var callerCandidates = await roomRef.collection('callerCandidates').get();
    for (var document in callerCandidates.docs) {
      document.reference.delete();
    }

    await roomRef.delete();
  }
}

abstract class EndCallInterface {
  Future<void> hungUp(String roomId);
}

abstract class CallerInterface {
  void createRoom();

  void createCallerCollection();

  void addNewCallerCandidate(RTCIceCandidate candidate);
  void setNewOffer(RTCSessionDescription offer);

  Stream<Map<String, dynamic>> onNewAnswer();
  Stream<Map<String, dynamic>> onNewCalleeCandidate();

  String getRoomId();
}

abstract class CalleeInterface {
  void initRoom(String roomId);

  Future<bool> isRoomExist();

  void createCalleeCollection();

  void addNewCalleeCandidate(RTCIceCandidate candidate);

  Map<String, dynamic> getOffer();

  void setNewAnswer(RTCSessionDescription answer);

  Stream<Map<String, dynamic>> onNewCallerCandidate();
}
