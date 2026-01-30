import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdManager {
  static const String _deviceIdKey = 'votexa_device_id';
  static const storage = FlutterSecureStorage();
  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    // Return cached value if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // Try to retrieve from secure storage
    String? storedId = await storage.read(key: _deviceIdKey);
    
    if (storedId != null) {
      _cachedDeviceId = storedId;
      return storedId;
    }

    // Generate new ID if not found
    final newId = const Uuid().v4();
    await storage.write(key: _deviceIdKey, value: newId);
    _cachedDeviceId = newId;
    return newId;
  }

  static String getParticipantUuid() {
    return const Uuid().v4();
  }

  static String generatePollId() {
    return const Uuid().v4().substring(0, 8).toUpperCase();
  }
}
