import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_tutorial/firebase_options.dart';
import 'package:webrtc_tutorial/peer2peer_signaling.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.teal,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Peer2PeerSignaling signaling = Peer2PeerSignaling();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderers = RTCVideoRenderer();
  String? roomId;
  TextEditingController textEditingController = TextEditingController(text: '');

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    signaling.setState = () => setState(() {});
    _localRenderer.initialize();
    _remoteRenderers.initialize();

    signaling.onAddRemoteStreams = ((streams) async {
      _remoteRenderers.srcObject = streams;
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderers.dispose();
    super.dispose();
  }

  double getDivide(int width, int height) {
    if (width != 0 && height != 0) {
      return width / height;
    } else {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // final size = MediaQuery.of(context).size;
    final double aspectRatio = getDivide(
      _localRenderer.videoWidth,
      _localRenderer.videoHeight,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome to Flutter Explained - WebRTC"),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              onTap: () {
                setState(() {});
              },
              title: const Text('Set state'),
            ),
            ListTile(
              onTap: () {
                signaling.microphoneSwitch().then((value) => setState(() {}));
              },
              title: const Text('Microphone'),
              trailing: Icon(
                signaling.microphoneEnabled ? Icons.mic : Icons.mic_off,
              ),
            ),
            ListTile(
              onTap: () {
                signaling.cameraSwitch().then((value) => setState(() {}));
              },
              title: const Text('Camera'),
              trailing: Icon(
                signaling.cameraEnabled ? Icons.videocam : Icons.videocam_off,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 90,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    scrollDirection: Axis.horizontal,
                    // mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 8,
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          roomId = await signaling.createRoom(_localRenderer);
                          textEditingController.text = roomId!;
                          // print('Room id is :$roomId');
                          setState(() {});
                        },
                        child: const Text("Create room"),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Add roomId
                          roomId = textEditingController.text.trim();
                          signaling.joinRoom(
                            roomId!,
                            _localRenderer,
                          );
                        },
                        child: const Text("Join room"),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          signaling.hangUp(_localRenderer, roomId);
                        },
                        child: const Text("Hangup"),
                      )
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Room: "),
                      Flexible(
                        child: TextFormField(
                          controller: textEditingController,
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    final double aspectRatio = getDivide(
                      _remoteRenderers.videoWidth,
                      _remoteRenderers.videoHeight,
                    );
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 125,
                        height: 400 * aspectRatio,
                        child: RTCVideoView(_remoteRenderers),
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20))
            ],
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 125,
                  height: 125 * aspectRatio,
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
