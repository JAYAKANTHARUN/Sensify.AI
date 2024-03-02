import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:servista/vision_helpers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_vibrate/flutter_vibrate.dart';

class ObjectTrackingPage extends StatefulWidget {
  const ObjectTrackingPage({super.key});
  @override
  State<ObjectTrackingPage> createState() => _ObjectTrackingPageState();
}

class _ObjectTrackingPageState extends State<ObjectTrackingPage> {
  late CameraController _controller;
  bool _isCameraReady = false;
  XFile? imageFile;
  String _text = '';
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _speakWelcome();
  }

  Future<void> _speakWelcome() async {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setPitch(1.0);
    await flutterTts.speak("Interaction Mode Activated");
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
    );

    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCameraReady = true;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interaction Mode'),
      ),
      body: Column(
        children: [
          _isCameraReady
              ? CameraPreview(_controller)
              : const Center(child: CircularProgressIndicator()),
          Text(_text)
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Vibrate.feedback(FeedbackType.heavy);
          if (!_controller.value.isInitialized) {
            return;
          }

          try {
            bool isListening = await _speech.initialize();
            if (!isListening) {
              print('Failed to start listening for speech.');
              return;
            }

            // Listen for speech input
            await _speech.listen(
              onResult: (result) {
                setState(() {
                  _text = result.recognizedWords;
                });
              },
            );
            // Wait for speech to text process to complete
            while (_text == null) {
              await Future.delayed(Duration(milliseconds: 100));
            }
            print(_text);

            // Take picture after speech to text process is complete
            final image = await _controller.takePicture();
            final bytes = await image.readAsBytes();
            final base64String = base64Encode(bytes);
            print(base64String);
            VisionHelpers.sendImageToServer(
                base64String, _text); // You can use this base64String as needed

            setState(() {
              imageFile = image;
            });
          } catch (e) {
            print(e);
          }
        },
        child: const Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
