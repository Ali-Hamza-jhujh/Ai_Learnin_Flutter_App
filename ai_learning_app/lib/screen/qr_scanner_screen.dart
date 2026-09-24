import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _hasScanned = false;
  int _detectCallbackCount = 0;
  int _barcodesFoundCount = 0;
  StreamSubscription<Object?>? _subscription;

  @override
  void initState() {
    super.initState();
    debugPrint('QR Scanner initState called');
    WidgetsBinding.instance.addObserver(this);
    _subscription = _controller.barcodes.listen(_handleBarcode);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        debugPrint('App paused/stopped, stopping scanner');
        return;
      case AppLifecycleState.resumed:
        debugPrint('App resumed, restarting scanner');
        // Restart the scanner when the app is resumed
        // Don't forget to resume listening to the barcode events
        _subscription = _controller.barcodes.listen(_handleBarcode);
        _controller.start().catchError((error) {
          debugPrint('Error starting camera on resume: $error');
        });
      case AppLifecycleState.inactive:
        debugPrint('App inactive, stopping scanner');
        // Stop the scanner when the app is paused
        // Also stop the barcode events subscription
        _subscription?.cancel();
        _subscription = null;
        _controller.stop().catchError((error) {
          debugPrint('Error stopping camera: $error');
        });
    }
  }

  void _handleBarcode(BarcodeCapture capture) {
    _detectCallbackCount++;
    debugPrint('=== QR Detection Event #$_detectCallbackCount ===');
    debugPrint('Barcodes count: ${capture.barcodes.length}');
    
    if (_hasScanned) {
      debugPrint('Already scanned, ignoring');
      return;
    }
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      debugPrint('No barcodes detected in this frame');
    } else {
      _barcodesFoundCount++;
      debugPrint('Barcodes found: $_barcodesFoundCount');
    }
    
    for (int i = 0; i < barcodes.length; i++) {
      final barcode = barcodes[i];
      final String? rawValue = barcode.rawValue;
      debugPrint('Barcode #$i:');
      debugPrint('  Format: ${barcode.format}');
      debugPrint('  Raw value: $rawValue');
      debugPrint('  Value is null: ${rawValue == null}');
      debugPrint('  Value is empty: ${rawValue?.isEmpty ?? true}');
      
      if (rawValue != null && rawValue.isNotEmpty) {
        debugPrint('Processing valid barcode: $rawValue');
        _processScannedCode(rawValue);
        break;
      }
    }
  }

  @override
  void dispose() {
    debugPrint('QR Scanner dispose called - total detections: $_detectCallbackCount, barcodes found: $_barcodesFoundCount');
    // Stop listening to lifecycle changes
    WidgetsBinding.instance.removeObserver(this);
    // Stop listening to the barcode events
    _subscription?.cancel();
    _subscription = null;
    // Dispose the controller
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAndScanImage() async {
    if (_hasScanned) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) return;

      debugPrint('Image selected for gallery scan: ${image.path}');

      final BarcodeCapture? capture = await _controller.analyzeImage(image.path);

      if (!mounted) return;

      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          final String? rawValue = barcode.rawValue;
          if (rawValue != null && rawValue.isNotEmpty) {
            _processScannedCode(rawValue);
            return;
          }
        }
      }

      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('No QR Code Detected'),
          content: const Text('Could not find a valid QR code in the selected image. Please select an image with a clear invite QR code.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(_),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error scanning image from gallery: $e');
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Gallery Error'),
          content: Text('Failed to analyze image: ${e.toString()}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(_),
            ),
          ],
        ),
      );
    }
  }

  void _processScannedCode(String rawValue) {
    debugPrint('=== Processing Scanned Code ===');
    debugPrint('Raw value: "$rawValue"');
    debugPrint('Raw value length: ${rawValue.length}');
    
    if (!mounted) {
      debugPrint('Widget not mounted, aborting');
      return;
    }
    
    setState(() => _hasScanned = true);
    debugPrint('Set _hasScanned to true');

    // Parse the code: either extract query param `code` from URL or use raw value
    String code = rawValue.trim();
    debugPrint('Trimmed code: "$code"');
    
    // Try to extract code from URL format
    if (code.contains('code=')) {
      debugPrint('Code contains "code=", trying to parse as URL');
      try {
        final uri = Uri.parse(code);
        final extractedCode = uri.queryParameters['code'];
        if (extractedCode != null && extractedCode.isNotEmpty) {
          code = extractedCode;
          debugPrint('Extracted code from URL: "$code"');
        }
      } catch (e) {
        debugPrint('Error parsing URL: $e');
      }
    }
    
    // Clean the code - remove any non-alphanumeric characters
    final originalCode = code;
    code = code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    debugPrint('Cleaned code: "$code" (was "$originalCode")');
    
    // Limit to 6 characters if it looks like an invite code
    if (code.length > 6) {
      code = code.substring(0, 6);
      debugPrint('Limited code to 6 characters: "$code"');
    }

    debugPrint('Final processed code: "$code"');
    debugPrint('Code length: ${code.length}');

    if (code.length >= 4) { // Accept codes of 4-6 characters
      debugPrint('Code is valid (length >= 4), navigating back');
      Navigator.pop(context, code);
    } else {
      debugPrint('Code is invalid (length < 4), showing error dialog');
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Invalid QR Code'),
          content: Text('Scanned code: "$code" is not a valid invite code. Invite codes should be 4-6 characters.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.pop(_);
                setState(() => _hasScanned = false);
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.bgCard.withValues(alpha: 0.8),
        middle: const Text('Scan Invite QR',
            style: TextStyle(color: AppColors.textWhite)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: AppColors.cyan),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.photo, color: AppColors.cyan),
          onPressed: _pickAndScanImage,
        ),
      ),
      child: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) {
              debugPrint('MobileScanner error: $error');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text('Camera Error', style: TextStyle(color: Colors.white, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text('Camera not available. Use gallery instead.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    CupertinoButton.filled(
                      child: const Text('Use Gallery'),
                      onPressed: _pickAndScanImage,
                    ),
                  ],
                ),
              );
            },
          ),

          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Align QR code inside the box to scan',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

