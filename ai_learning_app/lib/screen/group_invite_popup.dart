import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_theme.dart';

class GroupInvitePopup extends StatelessWidget {
  final String groupName;
  final String inviteCode;

  const GroupInvitePopup({super.key, required this.groupName, required this.inviteCode});

  Future<void> _shareInvite(BuildContext context) async {
    final String joinUrl = 'https://lumio.study/join?code=$inviteCode';
    final String shareText = 'Join my study group "$groupName" on StudyApp!\n\n'
        'Click the link to join directly: $joinUrl\n\n'
        'Or use invite code: $inviteCode';

    try {
      final qrValidationResult = QrValidator.validate(
        data: joinUrl,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.Q,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );

        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/invite_qr_${inviteCode}.png';
        final file = File(path);

        const double size = 512.0;
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(size, size));
        final picture = recorder.endRecording();
        final ui.Image img = await picture.toImage(size.toInt(), size.toInt());
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          await file.writeAsBytes(byteData.buffer.asUint8List());
          await Share.shareXFiles(
            [XFile(path, mimeType: 'image/png')],
            text: shareText,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Error generating/sharing QR image: $e');
    }

    // Fallback if image generation fails
    await Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Invite to $groupName', style: const TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Share this code or scan the QR to join', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: 'https://lumio.study/join?code=$inviteCode',
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Text(inviteCode, style: const TextStyle(color: AppColors.cyan, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              color: AppColors.violet,
              borderRadius: BorderRadius.circular(16),
              onPressed: () => _shareInvite(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.share, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Share via WhatsApp/SMS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

