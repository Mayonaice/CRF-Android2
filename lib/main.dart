import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/prepare_mode_screen.dart';
import 'screens/return_mode_screen.dart';
import 'screens/return_page.dart'; // Tambahkan import untuk ReturnModePage
import 'screens/profile_menu_screen.dart';
import 'screens/device_info_screen.dart';
import 'screens/return_validation_screen.dart';
import 'screens/tl_home_page.dart';
import 'screens/tl_device_info_screen.dart';
import 'screens/tl_profile_screen.dart';
import 'screens/tl_qr_scanner_screen.dart';
import 'screens/konsol_mode_screen.dart';
import 'screens/konsol_data_return_screen.dart';
import 'screens/konsol_data_pengurangan_screen.dart';
import 'screens/konsol_data_closing_screen.dart';
import 'screens/konsol_data_closing_form_screen.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'widgets/notification_listener_widget.dart';

// Method channel for native communication
const MethodChannel _channel = MethodChannel('com.advantage.crf_android/app_channel');

// Function to enable fullscreen mode
Future<void> enableFullscreen() async {
  try {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('toggleFullscreen', {'enable': true});
    }
  } catch (e) {
    debugPrint('Error enabling fullscreen: $e');
  }
}

// Function to disable fullscreen mode
Future<void> disableFullscreen() async {
  try {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('toggleFullscreen', {'enable': false});
    }
  } catch (e) {
    debugPrint('Error disabling fullscreen: $e');
  }
}

// Global error handler
void _handleError(Object error, StackTrace stack) {
  debugPrint('CRITICAL ERROR: $error');
  debugPrintStack(stackTrace: stack);
}

// SafePrefs Class to handle all preference operations safely
class SafePrefs {
  static Future<void> clearAll() async {
    try {
      // Clear preferences if they exist
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('Preferences cleared successfully');
    } catch (e) {
      debugPrint('Failed to clear preferences: $e');
    }
  }
}

class CrfSplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;
  
  const CrfSplashScreen({Key? key, required this.onInitializationComplete}) : super(key: key);

  @override
  State<CrfSplashScreen> createState() => _CrfSplashScreenState();
}

class _CrfSplashScreenState extends State<CrfSplashScreen> {
  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  String _errorDetails = '';
  
  @override
  void initState() {
    super.initState();
    // Ensure fullscreen mode is enabled
    enableFullscreen();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Add a small delay for UI to render
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      // Update status message
      if (mounted) setState(() => _statusMessage = 'Setting up environment...');
      
      // Update status
      if (mounted) setState(() => _statusMessage = 'Setting display orientation...');
      
      // Set orientation - with graceful fallback
      try {
        // Only set orientation on Android
        if (Platform.isAndroid) {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      } catch (e) {
        debugPrint('Failed to set orientation: $e');
      }
      
      // Update status
      if (mounted) setState(() => _statusMessage = 'Configuring UI...');
      
      // Try to set UI style but don't crash if it fails
      try {
        if (Platform.isAndroid) {
          SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
            statusBarColor: Color(0xFF0056A4),
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF0056A4),
            systemNavigationBarIconBrightness: Brightness.light,
          ));
        }
      } catch (e) {
        debugPrint('Failed to set system UI style: $e');
      }
      
      // Update status
      if (mounted) setState(() => _statusMessage = 'Initializing data services...');

      // Verify shared preferences access 
      try {
        final prefs = await SharedPreferences.getInstance();
        // Try simple write/read test
        await prefs.setString('_test_key', 'test_value');
        final testValue = prefs.getString('_test_key');
        debugPrint('SharedPreferences test: $testValue');
        await prefs.remove('_test_key');
      } catch (e) {
        debugPrint('SharedPreferences test failed: $e');
        throw Exception('Unable to access app storage: $e');
      }

      // Add a small delay to ensure all async tasks have completed
      await Future.delayed(const Duration(seconds: 1));
      
      // Update status to indicate completion
      if (mounted) setState(() => _statusMessage = 'Initialization complete!');
      
      // Add a small delay to show the "Initialization complete!" message
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Call the callback to signal completion
      if (mounted) {
        widget.onInitializationComplete();
      }
    } catch (error, stack) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorDetails = 'Error: ${error.toString()}\n${stack.toString().split('\n').take(3).join('\n')}';
          _statusMessage = 'Initialization failed';
        });
      }
      _handleError(error, stack);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF29CC29), // Changed to green background
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Removed image and replaced with a simple logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'CRF',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF29CC29),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'CRF APP',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              if (_hasError)
                Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorDetails,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        // Clear data and try again
                        await SafePrefs.clearAll();
                        if (mounted) {
                          setState(() {
                            _hasError = false;
                            _statusMessage = 'Retrying...';
                          });
                          _initializeApp();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF29CC29), // Updated color to match background
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3.0, // Slightly thicker progress indicator
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  // Set error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _handleError(details.exception, details.stack ?? StackTrace.current);
  };
  
  // Tambahkan log debugging
  print('🚀 Starting CRF Android application...');
  
  // Set up zone-level error handling
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Enable fullscreen mode
    enableFullscreen();
    
    // Run the app
    runApp(const CrfApp());
  }, (error, stackTrace) {
    _handleError(error, stackTrace);
  });
}

class CrfApp extends StatefulWidget {
  const CrfApp({Key? key}) : super(key: key);

  @override
  State<CrfApp> createState() => _CrfAppState();
}

class _CrfAppState extends State<CrfApp> {
  bool _isInitialized = false;

  void _handleInitializationComplete() {
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListenerWidget(
      child: MaterialApp(
        debugShowCheckedModeBanner: false, // Hapus badge DEBUG di pojok kanan atas
        title: 'CRF App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: _isInitialized ? const LoginPage() : CrfSplashScreen(
          onInitializationComplete: _handleInitializationComplete,
        ),
        routes: {
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
          '/prepare_mode': (context) => const PrepareModePage(),
          '/return_page': (context) => const ReturnModePage(),
          '/profile': (context) => const ProfileMenuScreen(),
          '/device_info': (context) => const DeviceInfoScreen(),
          '/return_validation': (context) => const ReturnValidationScreen(),
          '/tl_home': (context) => const TLHomePage(),
          '/tl_device_info': (context) => const TLDeviceInfoScreen(),
          '/tl_profile': (context) => const TLProfileScreen(),
          '/tl_qr_scanner': (context) => const TLQRScannerScreen(),
          '/konsol_mode': (context) => const KonsolModePage(),
          '/konsol_data_return': (context) => const KonsolDataReturnPage(),
          '/konsol_data_pengurangan': (context) => const KonsolDataPenguranganPage(),
          '/konsol_data_closing': (context) => const KonsolDataClosingPage(),
          '/konsol_data_closing_form': (context) => const KonsolDataClosingFormScreen(),
        },
      ),
    );
  }
}
