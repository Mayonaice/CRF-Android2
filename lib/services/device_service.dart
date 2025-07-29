import 'dart:io';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:android_id/android_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static const AndroidId _androidIdPlugin = AndroidId();
  
  // Keys for storing device ID
  static const String DEVICE_ID_KEY = 'persistent_device_id';
  static const String DEVICE_ID_CREATED_AT = 'device_id_created_at';
  static const String SECURE_DEVICE_ID_KEY = 'secure_device_id';
  
  // Test device ID constant
  static const String TEST_DEVICE_ID = '1234567fortest89';
  
  // Secure storage for more permanent storage
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  /// Get Android ID - Real device AndroidID for production
  /// Returns 16-character AndroidID for registration validation
  static Future<String> getDeviceId() async {
    try {
      print('🔍 Getting device ID with persistence');
      
      // First check secure storage (most reliable across reinstalls)
      final String? secureId = await _getSecureDeviceId();
      if (secureId != null && secureId.isNotEmpty) {
        print('✅ Using secure stored device ID: $secureId');
        return secureId;
      }
      
      // Then check shared preferences as fallback
      final String? storedId = await _getStoredDeviceId();
      if (storedId != null && storedId.isNotEmpty) {
        print('✅ Using stored persistent device ID: $storedId');
        // Also save to secure storage for future use
        await _storeSecureDeviceId(storedId);
        return storedId;
      }
      
      // If no stored ID, generate a new one and store it
      print('⚠️ No stored device ID found, generating new one');
      final String newId = await _generateDeviceId();
      await _storeDeviceId(newId);
      await _storeSecureDeviceId(newId);
      return newId;
    } catch (e) {
      print('❌ Error in getDeviceId: $e');
      return TEST_DEVICE_ID;
    }
  }
  
  /// Get stored device ID from SharedPreferences
  static Future<String?> _getStoredDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(DEVICE_ID_KEY);
    } catch (e) {
      print('❌ Error getting stored device ID: $e');
      return null;
    }
  }
  
  /// Store device ID in SharedPreferences
  static Future<bool> _storeDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(DEVICE_ID_KEY, deviceId);
      await prefs.setString(DEVICE_ID_CREATED_AT, DateTime.now().toIso8601String());
      print('✅ Device ID stored successfully: $deviceId');
      return true;
    } catch (e) {
      print('❌ Error storing device ID: $e');
      return false;
    }
  }
  
  /// Get device ID from secure storage (survives app reinstalls)
  static Future<String?> _getSecureDeviceId() async {
    try {
      return await _secureStorage.read(key: SECURE_DEVICE_ID_KEY);
    } catch (e) {
      print('❌ Error getting secure device ID: $e');
      return null;
    }
  }
  
  /// Store device ID in secure storage
  static Future<void> _storeSecureDeviceId(String deviceId) async {
    try {
      await _secureStorage.write(key: SECURE_DEVICE_ID_KEY, value: deviceId);
      print('✅ Device ID stored securely: $deviceId');
    } catch (e) {
      print('❌ Error storing secure device ID: $e');
    }
  }
  
  /// Generate a device ID based on hardware information
  static Future<String> _generateDeviceId() async {
    try {
      print('🔍 Generating device ID from hardware info');
      
      if (Platform.isAndroid) {
        print('🔍 Android platform detected');
        
        // Try to get native Android ID first
        String? nativeAndroidId = await _androidIdPlugin.getId();
        print('🔍 Native Android ID: $nativeAndroidId');
        
        if (nativeAndroidId != null && nativeAndroidId.isNotEmpty && nativeAndroidId != 'unknown') {
          print('✅ Using native Android ID: $nativeAndroidId');
          return nativeAndroidId;
        }
        
        // Fallback to device-specific info
        print('⚠️ Native Android ID not available, using device info');
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
        
        // Collect device-specific information that doesn't change on reinstall
        final List<String> deviceIdentifiers = [
          androidInfo.brand ?? '',
          androidInfo.model ?? '',
          androidInfo.manufacturer ?? '',
          androidInfo.board ?? '',
          androidInfo.hardware ?? '',
          androidInfo.display ?? '',
          androidInfo.product ?? '',
          androidInfo.device ?? '',
          // Add more hardware-specific identifiers
          androidInfo.serialNumber ?? '', // This is often empty on newer Android versions due to permissions
          androidInfo.host ?? '',
          androidInfo.bootloader ?? '',
          androidInfo.tags ?? '',
          androidInfo.type ?? '',
        ];
        
        // Create a stable identifier by hashing device properties
        final String deviceData = deviceIdentifiers.join('|');
        final String deviceHash = sha256.convert(utf8.encode(deviceData)).toString().substring(0, 16);
        
        print('✅ Generated device hash: $deviceHash');
        return deviceHash;
      } else if (Platform.isIOS) {
        print('🔍 iOS platform detected');
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        
        // Use iOS identifier
        String iosId = iosInfo.identifierForVendor ?? TEST_DEVICE_ID;
        print('✅ iOS ID: $iosId');
        return iosId;
      } else {
        print('🔍 Web/Desktop platform detected');
        return TEST_DEVICE_ID;
      }
    } catch (e) {
      print('❌ Error generating device ID: $e');
      return TEST_DEVICE_ID;
    }
  }
  
  /// Get detailed device information
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      String persistentDeviceId = await getDeviceId();
      
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
        String? nativeAndroidId = await _androidIdPlugin.getId();
        
        return {
          'deviceId': persistentDeviceId,
          'nativeAndroidId': nativeAndroidId ?? 'unknown',
          'originalId': androidInfo.id ?? 'unknown',
          'brand': androidInfo.brand ?? 'unknown',
          'model': androidInfo.model ?? 'unknown',
          'manufacturer': androidInfo.manufacturer ?? 'unknown',
          'androidVersion': androidInfo.version.release ?? 'unknown',
          'platform': 'Android',
          'isPersistent': 'true',
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        return {
          'deviceId': persistentDeviceId,
          'originalId': iosInfo.identifierForVendor ?? 'unknown',
          'name': iosInfo.name ?? 'unknown',
          'model': iosInfo.model ?? 'unknown',
          'systemName': iosInfo.systemName ?? 'unknown',
          'systemVersion': iosInfo.systemVersion ?? 'unknown',
          'platform': 'iOS',
          'isPersistent': 'true',
        };
      } else {
        return {
          'deviceId': persistentDeviceId,
          'platform': Platform.operatingSystem,
          'isPersistent': 'true',
        };
      }
    } catch (e) {
      print('❌ Error getting device info: $e');
      return {
        'deviceId': 'error_fallback_id',
        'error': e.toString(),
        'platform': 'Unknown',
        'isPersistent': 'false',
      };
    }
  }
  
  /// Check if device has a stored ID
  static Future<bool> hasStoredDeviceId() async {
    final secureId = await _getSecureDeviceId();
    if (secureId != null && secureId.isNotEmpty) {
      return true;
    }
    
    final storedId = await _getStoredDeviceId();
    return storedId != null && storedId.isNotEmpty;
  }
  
  /// Reset stored device ID (for testing only)
  static Future<bool> resetDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(DEVICE_ID_KEY);
      await prefs.remove(DEVICE_ID_CREATED_AT);
      await _secureStorage.delete(key: SECURE_DEVICE_ID_KEY);
      print('✅ Device ID reset successfully');
      return true;
    } catch (e) {
      print('❌ Error resetting device ID: $e');
      return false;
    }
  }
} 