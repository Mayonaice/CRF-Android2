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
import '../widgets/custom_modals.dart';

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
  
  // Auth service
  final AuthService _authService = AuthService();

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
    super.dispose();
  }

  // Flags to track modal and input states
  bool _isModalShowing = false;
  bool _inputChangedAfterModal = false;

  // Auto-fetch branches when all 3 fields are filled
  void _onFieldChanged() {
    // Mark that input has changed
    _inputChangedAfterModal = true;
    
    // If a modal is currently showing, don't try to fetch branches
    if (_isModalShowing) {
      return;
    }

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
            !_isLoadingBranches &&
            !_isModalShowing) {
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
    if (_isLoadingBranches || _isModalShowing) return;
    
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
        // Clear branches on error
        setState(() {
          _availableBranches.clear();
          _selectedBranch = null;
        });
        
        // Show error modal if it's not just empty fields
        if (_usernameController.text.isNotEmpty && 
            _passwordController.text.isNotEmpty && 
            _noMejaController.text.isNotEmpty) {
          // Set flag to prevent multiple modals
          _isModalShowing = true;
          
          await CustomModals.showFailedModal(
            context: context,
            message: result['message'] ?? 'Tidak dapat menemukan cabang untuk user ini. Periksa kembali username, password, dan nomor meja.',
            onPressed: () {
              Navigator.of(context).pop();
              // Reset flag when modal is closed
              _isModalShowing = false;
              // Reset input changed flag
              _inputChangedAfterModal = false;
              
              // Schedule a check to fetch branches again if input has changed
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_inputChangedAfterModal && 
                    _usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty &&
                    _noMejaController.text.isNotEmpty) {
                  _fetchBranches();
                }
              });
            },
          );
        }
      }
    } catch (e) {
      // Clear branches on error
      setState(() {
        _availableBranches.clear();
        _selectedBranch = null;
      });
      
      // Show error modal for connection issues
      if (_usernameController.text.isNotEmpty && 
          _passwordController.text.isNotEmpty && 
          _noMejaController.text.isNotEmpty) {
        // Set flag to prevent multiple modals
        _isModalShowing = true;
        
        await CustomModals.showFailedModal(
          context: context,
          message: 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
          buttonText: 'Coba Lagi',
          onPressed: () {
            Navigator.of(context).pop();
            // Reset flag when modal is closed
            _isModalShowing = false;
            // Reset input changed flag
            _inputChangedAfterModal = false;
            // Try again
            _fetchBranches();
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBranches = false;
        });
      }
    }
  }

  // Modify _performLogin to handle test mode
  Future<void> _performLogin() async {
    // Don't proceed if a modal is already showing
    if (_isModalShowing) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }
     
    if (_availableBranches.isEmpty) {
      _isModalShowing = true;
      await CustomModals.showFailedModal(
        context: context,
        message: 'Pastikan semua field sudah benar. Tidak ada cabang CRF yang tersedia untuk user ini.',
        onPressed: () {
          Navigator.of(context).pop();
          _isModalShowing = false;
          _inputChangedAfterModal = false;
          
          // Schedule a check to fetch branches again if input has changed
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_inputChangedAfterModal && 
                _usernameController.text.isNotEmpty &&
                _passwordController.text.isNotEmpty &&
                _noMejaController.text.isNotEmpty) {
              _fetchBranches();
            }
          });
        },
      );
      return;
    }
     
    if (_selectedBranch == null && _availableBranches.length > 1) {
      _isModalShowing = true;
      await CustomModals.showFailedModal(
        context: context,
        message: 'Silahkan pilih cabang untuk melanjutkan login.',
        onPressed: () {
          Navigator.of(context).pop();
          _isModalShowing = false;
          _inputChangedAfterModal = false;
        },
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
       
      if (result['success']) {
        HapticFeedback.mediumImpact();
        
        _isModalShowing = true;
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Selamat datang di aplikasi CRF',
          buttonText: 'Lanjutkan',
          onPressed: () async {
            Navigator.pop(context); // Close modal
            _isModalShowing = false;
            _inputChangedAfterModal = false;
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
        _isModalShowing = true;
        if (result['errorType'] == 'ANDROID_ID_ERROR') {
          await CustomModals.showFailedModal(
            context: context,
            message: result['message'] ?? 'AndroidID belum terdaftar, silahkan hubungi tim COMSEC',
            onPressed: () {
              Navigator.of(context).pop();
              _isModalShowing = false;
              _inputChangedAfterModal = false;
              
              // Schedule a check to fetch branches again if input has changed
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_inputChangedAfterModal && 
                    _usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty &&
                    _noMejaController.text.isNotEmpty) {
                  _fetchBranches();
                }
              });
            },
          );
        } else if (result['message']?.toString().contains('Connection error') == true ||
                   result['message']?.toString().contains('Timeout') == true) {
          await CustomModals.showFailedModal(
            context: context,
            message: result['message'] ?? 'Koneksi ke server bermasalah',
            buttonText: 'Coba Lagi',
            onPressed: () {
              Navigator.of(context).pop();
              _isModalShowing = false;
              _inputChangedAfterModal = false;
              _performLogin();
            },
          );
        } else {
          await CustomModals.showFailedModal(
            context: context,
            message: result['message'] ?? 'Username atau password tidak valid',
            onPressed: () {
              Navigator.of(context).pop();
              _isModalShowing = false;
              _inputChangedAfterModal = false;
              
              // Schedule a check to fetch branches again if input has changed
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_inputChangedAfterModal && 
                    _usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty &&
                    _noMejaController.text.isNotEmpty) {
                  _fetchBranches();
                }
              });
            },
          );
        }
      }
    } catch (e) {
      _isModalShowing = true;
      await CustomModals.showFailedModal(
        context: context,
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        buttonText: 'Coba Lagi',
        onPressed: () {
          Navigator.of(context).pop();
          _isModalShowing = false;
          _inputChangedAfterModal = false;
          _performLogin();
        },
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Login box
                Container(
                  width: isTablet ? screenWidth * 0.5 : screenWidth * 0.85,
                  margin: EdgeInsets.only(top: screenHeight * 0.15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      // Login title
                      Padding(
                        padding: EdgeInsets.only(top: 20, bottom: 20),
                        child: Text(
                          'Login Yout Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0056A4),
                          ),
                        ),
                      ),
                      
                      // Form
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User ID field
                              Text(
                                'User ID/Email/No.Hp',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your User ID, Email or Phone Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                                  suffixIcon: Icon(Icons.person),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your username';
                                  }
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 15),
                              
                              // Password field
                              Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
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
                              
                              SizedBox(height: 15),
                              
                              // No. Meja field
                              Text(
                                'No. Meja',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              TextFormField(
                                controller: _noMejaController,
                                decoration: InputDecoration(
                                  hintText: 'Enter table number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                                  suffixIcon: Icon(Icons.table_chart),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter table number';
                                  }
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 15),
                              
                              // Group field
                              Text(
                                'Group',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
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
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                                ),
                                items: _availableBranches.map((branch) {
                                  return DropdownMenuItem<String>(
                                    value: branch['displayText'] as String,
                                    child: Text(
                                      (branch['displayText'] as String?) ?? '',
                                    ),
                                  );
                                }).toList(),
                                onChanged: _availableBranches.isEmpty ? null : (String? value) {
                                  setState(() {
                                    _selectedBranch = value;
                                  });
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
                              
                              // Login button
                              Container(
                                width: double.infinity,
                                margin: EdgeInsets.symmetric(vertical: 30),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _performLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF1976D2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              
                              // IMEI display
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 15),
                                  child: Text(
                                    'IMEI = $_androidId',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                      fontFamily: 'monospace',
                                    ),
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
                
                // Version info at bottom
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    'CRF Android App v1.0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}