import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ModelViewerScreen extends StatefulWidget {
  const ModelViewerScreen({super.key});

  @override
  State<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorText;

  final Map<String, String> _boneInfo = {
    'Cranium': 'Protects the brain and forms the structure of the face.',
    'Mandible': 'The lower jawbone — the only movable bone of the skull.',
    'Hyoid': 'A U-shaped bone in the neck that supports the tongue.',
    'Sternum': 'The breastbone — connects to the ribs via cartilage.',
    'Sacrum': 'A triangular bone at the base of the spine, connecting to the pelvis.',
    'Coccyx': 'The tailbone — the final segment of the vertebral column.',
    'l_oscoxa': 'Left hip bone — part of the pelvis.',
    'r_oscoxa': 'Right hip bone — part of the pelvis.',
    'l_clavicle': 'Left collarbone — connects the arm to the sternum.',
    'r_clavicle': 'Right collarbone — connects the arm to the sternum.',
    'l_scapula': 'Left shoulder blade.',
    'r_scapula': 'Right shoulder blade.',
    'l_humerus': 'Left upper arm bone.',
    'r_humerus': 'Right upper arm bone.',
    'l_radius': 'Left forearm bone (thumb side).',
    'r_radius': 'Right forearm bone (thumb side).',
    'l_ulna': 'Left forearm bone (pinky side).',
    'r_ulna': 'Right forearm bone (pinky side).',
    'l_femur': 'Left femur — the longest, strongest bone in the body.',
    'r_femur': 'Right femur — the longest, strongest bone in the body.',
    'l_tibia': 'Left shinbone.',
    'r_tibia': 'Right shinbone.',
    'l_fibula': 'Left calf bone.',
    'r_fibula': 'Right calf bone.',
    'l_patella': 'Left kneecap.',
    'r_patella': 'Right kneecap.',
    'Xiphoid process': 'The small cartilaginous tip at the bottom of the sternum.',
    for (var i = 1; i <= 7; i++) 'c$i': 'Cervical vertebra $i (neck).',
    for (var i = 1; i <= 12; i++) 't$i': 'Thoracic vertebra $i (upper/mid back).',
    for (var i = 1; i <= 5; i++) 'l$i': 'Lumbar vertebra $i (lower back).',
    for (var i = 1; i <= 12; i++) 'l_rib$i': 'Left rib $i.',
    for (var i = 1; i <= 12; i++) 'r_rib$i': 'Right rib $i.',
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121624))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) => _handleMessage(msg.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadFlutterAsset('assets/models/viewer.html');
  }

  void _handleMessage(String message) {
    if (message.startsWith('__ALL_NAMES__')) {
      final raw = message.replaceFirst('__ALL_NAMES__', '');
      try {
        final List<dynamic> names = jsonDecode(raw);
        // ignore: avoid_print
        print('ALL BONE NAMES (${names.length}): ${names.join(", ")}');
      } catch (_) {}
      return;
    }
    if (message.startsWith('__ERROR__')) {
      setState(() => _errorText = message.replaceFirst('__ERROR__', ''));
      return;
    }
    _onBoneTapped(message);
  }

  String _prettyName(String raw) {
    var s = raw.replaceAll('__0', '').replaceAll('_0', '').trim();
    s = s.replaceAll('_', ' ');
    if (s.startsWith('l ')) s = 'Left ${s.substring(2)}';
    if (s.startsWith('r ')) s = 'Right ${s.substring(2)}';
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _onBoneTapped(String boneName) {
    final pretty = _prettyName(boneName);
    final desc = _boneInfo[boneName] ??
        'Part of the ${pretty.toLowerCase()} region.';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pretty,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(desc,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050818),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '3D Complete Body Model',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
          if (_errorText != null)
            Positioned(
              top: 12, left: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Model load error: $_errorText',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.hand_draw, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Rotate, pinch to zoom, tap a bone for info',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}