import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'home_page.dart';
import 'tl_home_page.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../widgets/error_dialogs.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _noMejaController = TextEditingController();
  String? _selectedBranch;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isLoadingBranches = false;
  List<Map<String, dynamic>> _availableBranches = [];
  String _androidId = 'Loading...'; // Store Android ID
  bool _isTestMode = false; // Test mode toggle
  
  // Auth service
  final AuthService _authService = AuthService();

  // Add controller for token input
  final TextEditingController _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Force portrait orientation for login page only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Set status bar color to match Android theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0056A4),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    // Check if user is already logged in
    _checkLoginStatus();
    
    // Load Android ID
    _loadAndroidId();
    
    // Add listeners to auto-fetch branches when all 3 fields are filled
    _usernameController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _noMejaController.addListener(_onFieldChanged);
  }
  
  // Check login status
  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn && mounted) {
      // Check user role and navigate accordingly
      final userData = await _authService.getUserData();
      // Prioritize roleID field as it's the field name from API
      String userRole = '';
      if (userData != null) {
        // Print all possible role fields for debugging
        print('DEBUG: Available role fields - roleID: ${userData['roleID']}, role: ${userData['role']}, userRole: ${userData['userRole']}');
        
        userRole = (userData['roleID'] ?? 
                   userData['RoleID'] ?? 
                   userData['role'] ?? 
                   userData['Role'] ?? 
                   userData['userRole'] ?? 
                   userData['UserRole'] ?? 
                   userData['position'] ?? 
                   userData['Position'] ?? 
                   '').toString().toUpperCase();
        print('DEBUG: User role from userData: $userRole');
      }
      
      if (userRole == 'CRF_TL') {
        print('DEBUG LOGIN STATUS: Navigating to TLHomePage for CRF_TL role');
        // Navigate to TL Home Page with portrait orientation using named route
        Navigator.of(context).pushReplacementNamed('/tl_home');
      } else {
        // Navigate to regular Home Page with landscape orientation for CRF_OPR
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  // Load Android ID
  Future<void> _loadAndroidId() async {
    try {
      final deviceId = await DeviceService.getDeviceId();
      if (mounted) {
        setState(() {
          _androidId = deviceId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _androidId = 'Error loading AndroidID';
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _noMejaController.removeListener(_onFieldChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _noMejaController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // Auto-fetch branches when all 3 fields are filled
  void _onFieldChanged() {
    // Check if all 3 fields have content
    if (_usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _noMejaController.text.isNotEmpty) {
      
      // Reset current branches and selected branch
      if (_availableBranches.isNotEmpty || _selectedBranch != null) {
        setState(() {
          _availableBranches.clear();
          _selectedBranch = null;
        });
      }
      
      // Debounce the API call (wait 500ms after user stops typing)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_usernameController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty &&
            _noMejaController.text.isNotEmpty &&
            !_isLoadingBranches) {
          _fetchBranches();
        }
      });
    } else {
      // Clear branches if any field is empty
      if (_availableBranches.isNotEmpty || _selectedBranch != null) {
        setState(() {
          _availableBranches.clear();
          _selectedBranch = null;
        });
      }
    }
  }

  // Fetch available branches
  Future<void> _fetchBranches() async {
    if (_isLoadingBranches) return;
    
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final result = await _authService.getUserBranches(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        _noMejaController.text.trim(),
      );
      
      if (result['success'] && result['data'] != null) {
        final branches = result['data'] as List<dynamic>;
        
        setState(() {
          _availableBranches = branches.map((branch) => {
            'branchName': branch['branchName'] ?? branch['BranchName'] ?? '',
            'roleID': branch['roleID'] ?? branch['RoleID'] ?? '',
            'displayText': '${branch['branchName'] ?? branch['BranchName'] ?? ''} (${branch['roleID'] ?? branch['RoleID'] ?? ''})',
          }).toList();
          
          // Auto-select if only one branch
          if (_availableBranches.length == 1) {
            _selectedBranch = _availableBranches.first['displayText'];
          }
        });
        
        // Show success feedback
        if (_availableBranches.isNotEmpty) {
          HapticFeedback.lightImpact();
        }
      } else {
        // Clear branches on error but don't show popup yet (user might still be typing)
        setState(() {
          _availableBranches.clear();
          _selectedBranch = null;
        });
      }
    } catch (e) {
      // Clear branches on error
      setState(() {
        _availableBranches.clear();
        _selectedBranch = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBranches = false;
        });
      }
    }
  }

  // Show test mode password dialog
  Future<void> _showTestModeDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Test Mode Authentication',
          style: TextStyle(fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter test password',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value != 'Test@123') {
                return 'Invalid test password';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isTestMode = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _isTestMode = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Enable',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Show token input dialog
  Future<void> _showTokenInputDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Test Mode Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Masukkan token Bearer yang valid:'),
              SizedBox(height: 10),
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  hintText: 'Bearer token...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _isTestMode = false);
                Navigator.of(context).pop();
              },
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => _loginWithToken(),
              child: Text('Login'),
            ),
          ],
        );
      },
    );
  }

  // Login with token
  Future<void> _loginWithToken() async {
    String token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Token tidak boleh kosong')),
      );
      return;
    }

    // Remove 'Bearer ' prefix if present
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7);
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.loginWithToken(token);
      
      if (result['success']) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Modify _performLogin to handle test mode
  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
     
    if (_availableBranches.isEmpty) {
      ErrorDialogs.showErrorDialog(
        context,
        title: 'Tidak Ada Akses',
        message: 'Pastikan semua field sudah benar. Tidak ada cabang CRF yang tersedia untuk user ini.',
        icon: Icons.business_outlined,
      );
      return;
    }
     
    if (_selectedBranch == null && _availableBranches.length > 1) {
      ErrorDialogs.showErrorDialog(
        context,
        title: 'Pilih Cabang',
        message: 'Silahkan pilih cabang untuk melanjutkan login.',
        icon: Icons.location_on_outlined,
        iconColor: Colors.orange,
      );
      return;
    }
  
    setState(() {
      _isLoading = true;
    });
  
    try {
      String? branchName;
      if (_selectedBranch != null) {
        final selectedBranchData = _availableBranches.firstWhere(
          (branch) => branch['displayText'] == _selectedBranch,
          orElse: () => _availableBranches.first,
        );
        branchName = selectedBranchData['branchName'];
      }
 
      final result = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        _noMejaController.text.trim(),
        selectedBranch: branchName,
      );
      
      // DEBUG: Check if token was stored properly
      final token = await _authService.getToken();
      debugPrint('🔴 DEBUG: Token after login: ${token != null ? "Found (${token.length} chars)" : "NULL"}');
       
      if (result['success'] || (_isTestMode && result['errorType'] == 'ANDROID_ID_ERROR')) {
        // startGlobalTokenRefresh(); // Removed as per edit hint
        
        HapticFeedback.mediumImpact();
         
        ErrorDialogs.showSuccessDialog(
          context,
          title: 'Login Berhasil!',
          message: _isTestMode ? 'Login berhasil (Test Mode)' : 'Selamat datang di aplikasi CRF',
          buttonText: 'Lanjutkan',
          onPressed: () async {
            Navigator.pop(context);
            if (mounted) {
              // Check user role and navigate accordingly
              final userData = await _authService.getUserData();
              // Prioritize roleID field as it's the field name from API
              String userRole = '';
              if (userData != null) {
                // Print all possible role fields for debugging
                print('DEBUG: Available role fields on login success - roleID: ${userData['roleID']}, role: ${userData['role']}, userRole: ${userData['userRole']}');
                 
                userRole = (userData['roleID'] ?? 
                           userData['RoleID'] ?? 
                           userData['role'] ?? 
                           userData['Role'] ?? 
                           userData['userRole'] ?? 
                           userData['UserRole'] ?? 
                           userData['position'] ?? 
                           userData['Position'] ?? 
                           '').toString().toUpperCase();
                print('DEBUG: User role from userData on login success: $userRole');
              }
          
              if (userRole == 'CRF_TL') {
                print('DEBUG LOGIN: Navigating to TLHomePage for CRF_TL role');
                // Navigate to TL Home Page with portrait orientation using named route
                Navigator.of(context).pushReplacementNamed('/tl_home');
              } else {
                // Navigate to regular Home Page with landscape orientation for CRF_OPR
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              }
            }
          },
        );
      } else {
        if (result['errorType'] == 'ANDROID_ID_ERROR') {
          ErrorDialogs.showErrorDialog(
            context,
            title: 'AndroidID Tidak Terdaftar',
            message: result['message'] ?? 'AndroidID belum terdaftar, silahkan hubungi tim COMSEC',
            icon: Icons.phone_android,
            iconColor: Colors.orange,
          );
        } else if (result['message']?.toString().contains('Connection error') == true ||
                   result['message']?.toString().contains('Timeout') == true) {
          ErrorDialogs.showConnectionErrorDialog(
            context,
            message: result['message'] ?? 'Koneksi ke server bermasalah',
            onRetry: _performLogin,
          );
        } else {
          ErrorDialogs.showErrorDialog(
            context,
            title: 'Login Gagal',
            message: result['message'] ?? 'Username atau password tidak valid',
            icon: Icons.login_outlined,
          );
        }
      }
    } catch (e) {
      ErrorDialogs.showConnectionErrorDialog(
        context,
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        onRetry: _performLogin,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0056A4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: screenHeight,
            width: screenWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg-login.png'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: 0, // Remove vertical padding to allow more space
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Add more space at the top to match original layout
                  SizedBox(height: screenHeight * 0.15),
                  
                  // Logo and form section with responsive width
                  Container(
                    width: isTablet ? screenWidth * 0.6 : screenWidth * 0.9,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Login text - responsive
                        Text(
                          'Login Your Account',
                          style: TextStyle(
                            fontSize: isTablet ? 28 : 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0056A4),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Form - responsive dengan padding tambahan
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: isTablet ? 20.0 : 10.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Username/ID/Email/HP
                                const Text(
                                  'User ID/Email/No.Hp',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your User ID, Email or Phone Number',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                    suffixIcon: const Icon(Icons.person),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your username';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 15),
                                
                                // Password
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your password',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible = !_isPasswordVisible;
                                        });
                                        // Android haptic feedback
                                        HapticFeedback.lightImpact();
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 15),
                                
                                // No. Meja
                                const Text(
                                  'No. Meja',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _noMejaController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter table number',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                    suffixIcon: const Icon(Icons.table_chart),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter table number';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 15),
                                
                                // Branch/Role dropdown (auto-populated)
                                Row(
                                  children: [
                                    const Text(
                                      'Branch & Role',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_isLoadingBranches) ...[
                                      const SizedBox(width: 10),
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                DropdownButtonFormField<String>(
                                  value: _selectedBranch,
                                  decoration: InputDecoration(
                                    hintText: _isLoadingBranches 
                                        ? 'Loading branches...'
                                        : _availableBranches.isEmpty 
                                            ? 'Fill all fields above to load branches'
                                            : 'Select branch & role',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    filled: true,
                                    fillColor: _availableBranches.isEmpty ? Colors.grey.shade100 : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                    suffixIcon: _isLoadingBranches 
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Icon(
                                            _availableBranches.isNotEmpty ? Icons.business : Icons.info_outline,
                                            color: _availableBranches.isNotEmpty ? null : Colors.grey,
                                          ),
                                  ),
                                  items: _availableBranches.map((branch) {
                                    return DropdownMenuItem<String>(
                                      value: branch['displayText'] as String,
                                      child: Text(
                                        (branch['displayText'] as String?) ?? '',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _availableBranches.isEmpty ? null : (String? value) {
                                    setState(() {
                                      _selectedBranch = value;
                                    });
                                    // Android haptic feedback
                                    HapticFeedback.selectionClick();
                                  },
                                  validator: (value) {
                                    if (_availableBranches.isEmpty) {
                                      return 'No branches available. Check your credentials.';
                                    }
                                    if (_availableBranches.length > 1 && value == null) {
                                      return 'Please select a branch';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 30),
                                
                                // Login button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _performLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2196F3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 3,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Login',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),

                                // Simple AndroidID display
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'IMEI = $_androidId',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Colors.black54,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Versi aplikasi dengan tulisan kecil di bagian bawah
                  Text(
                    'CRF Android App v1.0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  
                  // Add test mode switch in bottom corner
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, right: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Test Mode',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Switch(
                            value: _isTestMode,
                            onChanged: (value) {
                              if (value) {
                                _showTokenInputDialog();
                              } else {
                                setState(() {
                                  _isTestMode = false;
                                });
                              }
                            },
                            activeColor: Colors.greenAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}