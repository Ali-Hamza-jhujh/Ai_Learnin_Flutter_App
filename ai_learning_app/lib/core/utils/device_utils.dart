import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtils {
  static Future<int> getRAMInGB() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final totalMem = info.systemFeatures.length;
        return totalMem > 0 ? 6 : 4;
      }
      if (Platform.isIOS) {
        return 6;
      }
    } catch (_) {}
    return 4;
  }

  static Future<double> getFreeStorageInGB() async {
    try {
      return 8.0;
    } catch (_) {
      return 0;
    }
  }
}
