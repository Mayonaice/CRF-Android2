import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add clipboard import
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/return_model.dart';
import 'dart:async'; // Import for Timer
import '../widgets/barcode_scanner_widget.dart'; // Fix barcode scanner import
import '../widgets/checkmark_widget.dart'; // Add checkmark widget import

// CHECKMARK FIX: This file has been updated to fix the checkmark display issue.
// NEW APPROACH: Using stream-based barcode scanning for reliable checkmark validation
// Changes made:
// 1. Added stream listener for barcode results
// 2. Removed dependency on navigation return values
// 3. Direct state management for checkmark display
// 4. More reliable scanning validation system

void main() {
  runApp(const ReturnModeApp());
}

class ReturnModeApp extends StatelessWidget {
  const ReturnModeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Return Mode',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const ReturnModePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ReturnModePage extends StatefulWidget {
  const ReturnModePage({Key? key}) : super(key: key);

  @override
  State<ReturnModePage> createState() => _ReturnModePageState();
}

class _ReturnModePageState extends State<ReturnModePage> {
  final TextEditingController _idCRFController = TextEditingController();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  String _branchCode = '';
  String _errorMessage = '';
  bool _isLoading = false;
  
  // State untuk data return dan detail header
  ReturnHeaderResponse? _returnHeaderResponse;
  Map<String, dynamic>? _userData;

  // References to cartridge sections - now using a list to handle dynamic sections
  final List<GlobalKey<_CartridgeSectionState>> _cartridgeSectionKeys = [];
  
  // New ID Tool controller for all sections
  final TextEditingController _idToolController = TextEditingController();
  
  // Add jamMulai controller
  final TextEditingController _jamMulaiController = TextEditingController();
  
  // Timer for debouncing ID Tool typing
  Timer? _idToolTypingTimer;
  
  // TL approval controllers
  final TextEditingController _tlNikController = TextEditingController();
  final TextEditingController _tlPasswordController = TextEditingController();
  bool _isSubmitting = false;

  // NEW: Stream subscription for barcode results
  StreamSubscription<Map<String, dynamic>>? _barcodeStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupBarcodeStream();
  }

  // NEW: Setup stream listener for barcode scanning results
  void _setupBarcodeStream() {
    _barcodeStreamSubscription = BarcodeResultStream().stream.listen((result) {
      print('🎯 STREAM LISTENER: Received barcode result: $result');
      
      final String barcode = result['barcode'];
      final String fieldKey = result['fieldKey'];
      final String label = result['label'];
      final String? sectionId = result['sectionId']; // NEW: Get section ID
      
      // NEW: Only update the specific section that initiated the scan
      if (sectionId != null) {
        // Find the section with matching ID
        for (int i = 0; i < _cartridgeSectionKeys.length; i++) {
          final key = _cartridgeSectionKeys[i];
          if (key.currentState != null) {
            // Check if this is the target section
            final state = key.currentState!;
            if (state.sectionId == sectionId) {
              print('🎯 TARGETING SPECIFIC SECTION: $sectionId');
              state._handleStreamBarcodeResult(fieldKey, barcode, label);
              break; // Stop after finding the target section
            }
          }
        }
      } else {
        // Fallback: update all sections (old behavior)
        print('🎯 NO SECTION ID - UPDATING ALL SECTIONS');
        for (var key in _cartridgeSectionKeys) {
          if (key.currentState != null) {
            key.currentState!._handleStreamBarcodeResult(fieldKey, barcode, label);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _idCRFController.dispose();
    _tlNikController.dispose();
    _tlPasswordController.dispose();
    _idToolController.dispose();
    _jamMulaiController.dispose();
    _barcodeStreamSubscription?.cancel(); // Cancel stream subscription
    if (_idToolTypingTimer != null) {
      _idToolTypingTimer!.cancel();
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      setState(() {
        if (userData != null) {
          _userData = userData;
          
          // Log all user data for debugging
          print('DEBUG - Loading user data: $userData');
          print('DEBUG - User data keys: ${userData.keys.toList()}');
          
          // Extract and log the NIK value for debugging
          String userNIK = '';
          if (userData.containsKey('nik')) {
            userNIK = userData['nik'].toString();
          } else if (userData.containsKey('NIK')) {
            userNIK = userData['NIK'].toString();
          } else if (userData.containsKey('userId')) {
            userNIK = userData['userId'].toString();
          } else if (userData.containsKey('userID')) {
            userNIK = userData['userID'].toString();
          } else if (userData.containsKey('id')) {
            userNIK = userData['id'].toString();
          } else if (userData.containsKey('ID')) {
            userNIK = userData['ID'].toString();
          } else if (userData.containsKey('userName')) {
            userNIK = userData['userName'].toString();
          }
          print('DEBUG - Found NIK: $userNIK');
          
          // Ensure NIK exists in userData map
          if (userNIK.isNotEmpty && !userData.containsKey('nik')) {
            userData['nik'] = userNIK;
            print('DEBUG - Added NIK to userData: ${userData['nik']}');
          }
          
          // First try to get branchCode directly
          if (userData.containsKey('branchCode') && userData['branchCode'] != null && userData['branchCode'].toString().isNotEmpty) {
            _branchCode = userData['branchCode'].toString();
            print('Using branchCode from userData: $_branchCode');
          } 
          // Then try groupId as fallback
          else if (userData.containsKey('groupId') && userData['groupId'] != null && userData['groupId'].toString().isNotEmpty) {
            _branchCode = userData['groupId'].toString();
            print('Using groupId as branchCode: $_branchCode');
          }
          // Finally try BranchCode (different casing)
          else if (userData.containsKey('BranchCode') && userData['BranchCode'] != null && userData['BranchCode'].toString().isNotEmpty) {
            _branchCode = userData['BranchCode'].toString();
            print('Using BranchCode from userData: $_branchCode');
          }
          // Default to '1' if nothing found
          else {
            _branchCode = '1';
            print('No branch code found in userData, using default: $_branchCode');
          }
        } else {
          _branchCode = '1';
          print('No user data found, using default branch code: $_branchCode');
          
          // Create a default userData map with a NIK
          _userData = {'nik': '9190812021'};
          print('DEBUG - Created default userData with NIK: ${_userData!['nik']}');
        }
      });
    } catch (e) {
      setState(() {
        _branchCode = '1';
        print('Error loading user data: $e, using default branch code: $_branchCode');
        
        // Create a default userData map with a NIK
        _userData = {'nik': '9190812021'};
        print('DEBUG - Created default userData with NIK after error: ${_userData!['nik']}');
      });
    }
  }

  Future<void> _fetchReturnData() async {
    // DEBUG: Print current token to verify it's correctly stored
    try {
      final token = await _authService.getToken();
      debugPrint('🔴 DEBUG: Current token before fetch: ${token != null ? "Found (${token.length} chars)" : "NULL"}');
      
      // If token is null, try to log the user out and redirect to login page
      if (token == null || token.isEmpty) {
        debugPrint('🔴 DEBUG: Token is null or empty, forcing logout');
        
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        });
        
        // Show dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Sesi Berakhir'),
              content: const Text('Sesi anda telah berakhir. Silakan login kembali.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _authService.logout().then((_) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    });
                  },
                ),
              ],
            );
          },
        );
        return;
      }
      
      // Validate token before proceeding
      debugPrint('🔴 DEBUG: Validating token before fetch...');
      final isTokenValid = await _apiService.checkTokenValidity();
      if (!isTokenValid) {
        debugPrint('🔴 DEBUG: Token validation failed, forcing logout');
        
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        });
        
        // Show dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Sesi Berakhir'),
              content: const Text('Sesi anda telah berakhir. Silakan login kembali.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _authService.logout().then((_) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    });
                  },
                ),
              ],
            );
          },
        );
        return;
      }
      
      debugPrint('🔴 DEBUG: Token validation successful, proceeding with fetch');
    } catch (e) {
      debugPrint('🔴 DEBUG: Error getting token: $e');
    }
    
    final idCrf = _idCRFController.text.trim();
    if (idCrf.isEmpty) {
      _showErrorDialog('ID CRF tidak boleh kosong');
      return;
    }
    
    setState(() { 
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Debug: Print state before fetch
      print('Fetching return data for ID CRF: $idCrf');
      
      final response = await _apiService.getReturnHeaderAndCatridge(idCrf, branchCode: _branchCode);
      
      setState(() {
        if (response.success) {
          _returnHeaderResponse = response;
          _errorMessage = '';
          
          // Set jamMulai with current time
          final now = DateTime.now();
          _jamMulaiController.text = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          
          // Create the cartridge section keys based on the response
          _cartridgeSectionKeys.clear();
          if (response.data.isNotEmpty) {
            for (int i = 0; i < response.data.length; i++) {
              _cartridgeSectionKeys.add(GlobalKey<_CartridgeSectionState>());
            }
            
            // For debugging
            print('Created ${_cartridgeSectionKeys.length} cartridge section keys for ${response.data.length} catridges');
            for (int i = 0; i < response.data.length; i++) {
              print('Catridge ${i+1}: Code=${response.data[i].catridgeCode}, Type=${response.data[i].typeCatridge}, TypeTrx=${response.data[i].typeCatridgeTrx ?? "C"}');
            }
          }
        } else {
          _showErrorDialog(response.message);
        }
      });
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // If error is about serah terima, maybe provide a button to go to CPC
              if (message.contains('serah terima')) {
                // TODO: Navigate to CPC menu or show instructions
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sukses'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openBarcodeScanner() async {
    // TODO: Implementasi scan barcode dan set _idCRFController.text
  }

  // Check if all forms are valid
  bool get _isFormsValid {
    if (_cartridgeSectionKeys.isEmpty) return false;
    
    // Check all cartridge sections
    for (var key in _cartridgeSectionKeys) {
      if (!(key.currentState?.isFormValid ?? false)) {
        return false;
      }
    }
    
    return true;
  }

  // Show TL approval dialog
  Future<void> _showTLApprovalDialog() async {
    // Periksa apakah semua cartridge sections telah divalidasi
    bool allSectionsValidated = true;
    bool anyManualMode = false;
    
    for (var key in _cartridgeSectionKeys) {
      if (key.currentState != null) {
        // Jika section dalam mode manual, tandai
        if (key.currentState!._isManualMode) {
          anyManualMode = true;
        }
        // Jika section tidak dalam mode manual dan tidak semua field di-scan, tandai belum valid
        else if (!key.currentState!.allFieldsScanned) {
          allSectionsValidated = false;
          break;
        }
      }
    }
    
    // Jika semua section divalidasi dengan scan atau dalam mode manual, bisa langsung submit
    if (allSectionsValidated) {
      // Jika ada yang menggunakan mode manual, tetap minta approval TL
      if (anyManualMode) {
        _tlNikController.clear();
        _tlPasswordController.clear();
        
        return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Approval Team Leader'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Masukkan NIK dan Password Team Leader untuk approval:'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tlNikController,
                      decoration: const InputDecoration(
                        labelText: 'NIK TL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tlPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                _isSubmitting
                    ? const CircularProgressIndicator()
                    : TextButton(
                        child: const Text('Approve'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _validateTLAndSubmit();
                        },
                      ),
              ],
            );
          },
        );
      } else {
        // Jika semua divalidasi dengan scan dan tidak ada mode manual, langsung submit
        _submitReturnData();
      }
    } else {
      // Jika belum semua divalidasi, tampilkan pesan error
      _showErrorDialog('Harap lengkapi validasi scan untuk semua field atau gunakan mode manual');
    }
  }

  // Validate TL credentials and submit data
  Future<void> _validateTLAndSubmit() async {
    if (_tlNikController.text.isEmpty || _tlPasswordController.text.isEmpty) {
      _showErrorDialog('NIK dan Password TL harus diisi');
      return;
    }
    
    setState(() { _isSubmitting = true; });
    
    try {
      // Validate TL credentials
      final tlResponse = await _apiService.validateTLSupervisor(
        nik: _tlNikController.text,
        password: _tlPasswordController.text,
      );
      
      if (!tlResponse.success) {
        _showErrorDialog(tlResponse.message);
        setState(() { _isSubmitting = false; });
        return;
      }
      
      // 1. Update Planning RTN first - this is crucial for correct flow
      print('Updating Planning RTN...');
      final updateParams = {
        "idTool": _idToolController.text,
        "CashierReturnCode": _userData?['nik'] ?? '',
        "TableReturnCode": _userData?['tableCode'] ?? '',
        "DateStartReturn": DateTime.now().toIso8601String(),
        "WarehouseCode": _userData?['warehouseCode'] ?? 'Cideng',
        "UserATMReturn": _tlNikController.text,
        "SPVBARusak": _tlNikController.text,
        "IsManual": "N"
      };
      
      final updateResponse = await _apiService.updatePlanningRTN(updateParams);
      
      if (!updateResponse.success) {
        _showErrorDialog('Gagal update planning RTN: ${updateResponse.message}');
        setState(() { _isSubmitting = false; });
        return;
      }
      
      print('Planning RTN updated successfully!');
      
      // 2. Now insert each catridge data into RTN
      if (_returnHeaderResponse?.data == null || _returnHeaderResponse!.data.isEmpty) {
        _showErrorDialog('Tidak ada data catridge untuk diproses');
        setState(() { _isSubmitting = false; });
        return;
      }
      
      // Get NIK from userData with proper error checking
      String userNIK = '';
      if (_userData != null) {
        // Try all possible keys for NIK (case insensitive)
        if (_userData!.containsKey('nik')) {
          userNIK = _userData!['nik'].toString();
        } else if (_userData!.containsKey('NIK')) {
          userNIK = _userData!['NIK'].toString();
        } else if (_userData!.containsKey('userId')) {
          userNIK = _userData!['userId'].toString();
        } else if (_userData!.containsKey('userID')) {
          userNIK = _userData!['userID'].toString();
        } else if (_userData!.containsKey('id')) {
          userNIK = _userData!['id'].toString();
        } else if (_userData!.containsKey('ID')) {
          userNIK = _userData!['ID'].toString();
        }
        
        // Log the NIK value for debugging
        print('DEBUG - Using UserInput NIK: $userNIK');
        print('DEBUG - Available userData keys: ${_userData!.keys.toList()}');
        print('DEBUG - Complete userData: $_userData');
      } else {
        print('ERROR - userData is null, cannot get NIK');
      }
      
      // If NIK is still empty, use a hardcoded value to prevent API error
      if (userNIK.isEmpty) {
        print('WARNING - Using default NIK since userData does not contain NIK');
        userNIK = '9190812021'; // Default NIK to prevent API error
      }
      
      bool allSuccess = true;
      String errorMessage = '';
      
      // Process each catridge
      for (int i = 0; i < _returnHeaderResponse!.data.length; i++) {
        final catridge = _returnHeaderResponse!.data[i];
        
        print('Processing catridge ${i+1} of ${_returnHeaderResponse!.data.length}: ${catridge.catridgeCode}');
        print('DEBUG - Sending to API: idTool=${_idToolController.text}, userInput=$userNIK');
        
        // Send to RTN endpoint dengan parameter sesuai ketentuan
        final rtneResponse = await _apiService.insertReturnAtmCatridge(
          // field Id Tool diisi ke IdTool
          idTool: _idToolController.text,
          // field No Bag diisi ke BagCode
          bagCode: catridge.bagCode ?? '0',
          // field No Catridge diisi ke CatridgeCode
          catridgeCode: catridge.catridgeCode,
          // field Seal Code diisi ke SealCode
          sealCode: '0', // Use default or get from catridge data if available
          // field No Seal diisi ke CatridgeSeal
          catridgeSeal: catridge.catridgeSeal,
          // DenomCode diisi TEST
          denomCode: 'TEST',
          // qty default diisi 0
          qty: '0',
          // nik saat login yang tersimpan akan mengisi ke UserInput
          userInput: userNIK,
          // N untuk isBalikKaset
          isBalikKaset: "N",
          // CatridgeCodeOld diisi TEST
          catridgeCodeOld: "TEST",
          // Parameter scan status
          scanCatStatus: "TEST", 
          scanCatStatusRemark: "Processed from mobile app",
          scanSealStatus: "TEST",
          scanSealStatusRemark: "Processed from mobile app"
        );
        
        if (!rtneResponse.success) {
          allSuccess = false;
          errorMessage = rtneResponse.message;
          print('Failed to insert catridge ${catridge.catridgeCode}: ${rtneResponse.message}');
          break;
        }
        
        print('Successfully inserted catridge ${catridge.catridgeCode}');
      }
      
      setState(() { _isSubmitting = false; });
      
      if (allSuccess) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Berhasil'),
              content: const Text('Data return berhasil disimpan'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Return to home page
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        _showErrorDialog('Gagal menyimpan data return: $errorMessage');
      }
    } catch (e) {
      setState(() { _isSubmitting = false; });
      _showErrorDialog('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> _submitReturnData() async {
    if (_returnHeaderResponse == null || _returnHeaderResponse!.data.isEmpty) {
      setState(() { _errorMessage = 'Tidak ada data untuk disubmit'; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });
    
    try {
      // Check if we have any cartridge sections
      if (_cartridgeSectionKeys.isEmpty) {
        throw Exception('Tidak ada data catridge untuk disubmit');
      }
      
      // Get NIK from userData with proper error checking
      String userNIK = '';
      if (_userData != null) {
        // Try all possible keys for NIK (case insensitive)
        if (_userData!.containsKey('nik')) {
          userNIK = _userData!['nik'].toString();
        } else if (_userData!.containsKey('NIK')) {
          userNIK = _userData!['NIK'].toString();
        } else if (_userData!.containsKey('userId')) {
          userNIK = _userData!['userId'].toString();
        } else if (_userData!.containsKey('userID')) {
          userNIK = _userData!['userID'].toString();
        } else if (_userData!.containsKey('id')) {
          userNIK = _userData!['id'].toString();
        } else if (_userData!.containsKey('ID')) {
          userNIK = _userData!['ID'].toString();
        }
        
        // Log the NIK value for debugging
        print('DEBUG - Using UserInput NIK: $userNIK');
        print('DEBUG - Available userData keys: ${_userData!.keys.toList()}');
        print('DEBUG - Complete userData: $_userData');
      } else {
        print('ERROR - userData is null, cannot get NIK');
      }
      
      // If NIK is still empty, use a hardcoded value to prevent API error
      if (userNIK.isEmpty) {
        print('WARNING - Using default NIK since userData does not contain NIK');
        userNIK = '9190812021'; // Default NIK to prevent API error
      }
      
      bool allSuccess = true;
      
      // Submit data for each cartridge section
      for (int i = 0; i < _cartridgeSectionKeys.length; i++) {
        if (i >= _returnHeaderResponse!.data.length) break;
        
        final catridgeState = _cartridgeSectionKeys[i].currentState!;
        
        // Log the parameters being sent to the API
        print('DEBUG - Sending to API: idTool=${_idToolController.text}, userInput=$userNIK');
        
        // Implementasi parameter sesuai ketentuan
        final response = await _apiService.insertReturnAtmCatridge(
          // field Id Tool diisi ke IdTool
          idTool: _idToolController.text,
          // field No Bag diisi ke BagCode
          bagCode: catridgeState.bagCode ?? '',
          // field No Catridge diisi ke CatridgeCode
          catridgeCode: catridgeState.noCatridgeController.text,
          // field Seal Code diisi ke SealCode
          sealCode: catridgeState.sealCode ?? '',
          // field No Seal diisi ke CatridgeSeal
          catridgeSeal: catridgeState.noSealController.text,
          // DenomCode diisi TEST
          denomCode: 'TEST',
          // qty default diisi 0
          qty: '0',
          // nik saat login yang tersimpan akan mengisi ke UserInput - make sure this is filled
          userInput: userNIK,
          // N untuk isBalikKaset
          isBalikKaset: 'N',
          // CatridgeCodeOld diisi TEST
          catridgeCodeOld: 'TEST',
          // Parameter scan status
          scanCatStatus: "TEST",
          scanCatStatusRemark: "Processed from mobile app",
          scanSealStatus: "TEST",
          scanSealStatusRemark: "Processed from mobile app"
        );
        
        if (!response.success) {
          allSuccess = false;
          throw Exception(response.message);
        }
      }
      
      // Tampilkan dialog sukses
      _showSuccessDialog('Data return berhasil disubmit');
      
      // Reset form
      _idCRFController.clear();
      _idToolController.clear();
      setState(() {
        _returnHeaderResponse = null;
      });
      
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
      _showErrorDialog('Error submit data: ${e.toString()}');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Modified to fetch data by ID Tool
  Future<void> _fetchDataByIdTool(String idTool) async {
    if (idTool.isEmpty) {
      return;
    }
    
    setState(() { 
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Use a more direct approach to fetch data
      final result = await _apiService.validateAndGetReplenish(
              idTool: idTool,
        branchCode: _branchCode
      );

      if (result.success && result.data != null) {
        setState(() {
          // Create a header response with all the new fields
          _returnHeaderResponse = ReturnHeaderResponse(
            success: true,
            message: "Data ditemukan",
            header: ReturnHeaderData(
              atmCode: result.data!.atmCode,
              namaBank: result.data!.codeBank,
              lokasi: result.data!.lokasi,
              typeATM: result.data!.idTypeAtm,
              // Add new fields
              codeBank: result.data!.codeBank,
              jnsMesin: result.data!.jnsMesin,
              idTypeAtm: result.data!.idTypeAtm,
              timeSTReturn: result.data!.timeSTReturn,
            ),
            data: result.data!.catridges.map((c) => ReturnCatridgeData(
              idTool: result.data!.idToolPrepare,
              catridgeCode: c.catridgeCode,
              catridgeSeal: c.catridgeSeal,
              denomCode: '',
              typeCatridge: c.typeCatridgeTrx,
              bagCode: c.bagCode,
              sealCodeReturn: c.sealCodeReturn,
            )).toList(),
          );
          
          // Set current time to jam mulai when data is fetched successfully
          _setCurrentTime();
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
                });
              }
            }

  // Add method to set current time
  void _setCurrentTime() {
    final now = DateTime.now();
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _jamMulaiController.text = formattedTime;
  }

  // Method for building form fields with proper styling
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    String? hintText,
    bool hasIcon = false,
    bool enableScan = false,
    IconData iconData = Icons.search,
    VoidCallback? onIconPressed,
    required bool isSmallScreen,
    Function(String)? onChanged,
  }) {
    return Container(
      height: 45, // Fixed height for consistency with prepare mode
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Label section - fixed width
          SizedBox(
            width: 120, // Wider label (was 80/100)
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14, // Fixed size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Input field section with underline - expandable
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      readOnly: readOnly,
                      style: const TextStyle(fontSize: 14), // Fixed size
                      decoration: InputDecoration(
                        hintText: hintText,
                        contentPadding: const EdgeInsets.only(
                          left: 6,
                          right: 6,
                          bottom: 8,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: onChanged,
                    ),
                  ),
                  
                  // Icons positioned on the underline
                  if (enableScan)
                    Container(
                      width: 24, // Fixed width
                      height: 24, // Fixed height
                      margin: const EdgeInsets.only(
                        left: 6,
                        bottom: 4,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code_scanner,
                          color: Colors.blue,
                          size: 18, // Fixed size
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(), // Remove constraints
                        onPressed: onIconPressed,
                      ),
                    ),
                  
                  if (hasIcon)
                    Container(
                      width: 24, // Fixed width
                      height: 24, // Fixed height
                      margin: const EdgeInsets.only(
                        left: 6,
                        bottom: 4,
                      ),
                      child: Icon(
                        iconData,
                        color: Colors.grey,
                        size: 18, // Fixed size
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to scan ID Tool
  Future<void> _scanIdTool() async {
    try {
      // Navigate to barcode scanner with stream approach
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Scan ID Tool',
            fieldKey: 'idTool',
            fieldLabel: 'ID Tool',
            sectionId: null, // ID Tool doesn't belong to a specific section
            onBarcodeDetected: (String barcode) {
              // This will be handled by stream, but we still need the callback
              print('🎯 ID Tool callback: $barcode');
            },
          ),
        ),
      );
      
      // If no barcode was scanned (user cancelled), return early
      if (result == null) {
        print('ID Tool scanning cancelled');
        return;
      }
      
      String barcode = result;
      print('🎯 ID Tool scanned via navigation: $barcode');
      
      setState(() {
        _idToolController.text = barcode;
      });
      
      // Reset all scan validation states in all cartridge sections
      for (var key in _cartridgeSectionKeys) {
        if (key.currentState != null) {
          key.currentState!._resetAllScanStates();
        }
      }
      
      // Fetch data using the scanned ID Tool
      _fetchDataByIdTool(barcode);
    } catch (e) {
      print('Error opening barcode scanner: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka scanner: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTabletOrLandscapeMobile = size.width >= 600;
    final isLandscape = size.width > size.height;
    
    return Scaffold(
      appBar: null, // Remove default AppBar
      body: Column(
        children: [
          // Custom header - matched exactly with prepare_mode
          Container(
            height: 80, // Increased height to match prepare mode (was 60)
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button - bigger
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.red,
                    size: 30, // Increased size (was 24)
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 48),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 16),
                
                // Title - bigger
                const Text(
                  'Return Mode',
                  style: TextStyle(
                    fontSize: 22, // Increased size (was 20)
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                
                const Spacer(),
                
                // Branch info - bigger
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(
                      'JAKARTA-CIDENG',
                      style: TextStyle(
                        fontSize: 16, // Increased size (was 14)
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Meja : 010101',
                      style: TextStyle(
                        fontSize: 16, // Increased size (was 12)
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20), // Increased spacing (was 16)
                
                // CRF_OPR badge - bigger
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Increased padding
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'CRF_OPR',
                    style: TextStyle(
                      fontSize: 16, // Increased size (was 14)
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // User info - bigger
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: CircleAvatar(
                        radius: 20, // Increased size (was 18)
                        backgroundColor: Colors.grey.shade200,
                        child: ClipOval(
                          child: Image.network(
                            'https://randomuser.me/api/portraits/men/75.jpg',
                            width: 40, // Increased size (was 36)
                            height: 40, // Increased size (was 36)
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lorenzo Putra',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '9190812021',
                          style: TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Rest of the content
          Expanded(
            child: Container(
              color: Colors.white,
              child: RefreshIndicator(
                onRefresh: () async {
                  // Reset content
                  setState(() {
                    _returnHeaderResponse = null;
                    _idToolController.clear();
                    _jamMulaiController.clear();
                    _errorMessage = '';
                  });
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use Row for wide screens, Column for narrow screens
                    final useRow = constraints.maxWidth >= 600;
                    
                    // Create dynamic cartridge sections based on API response
                    List<Widget> cartridgeSections = [];
                    
                    // Loading indicator
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    // Error message if any
                    if (_errorMessage.isNotEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.red.shade100,
                        width: double.infinity,
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }
                    
                    // Clear and recreate keys when response changes
                    if (_returnHeaderResponse?.data != null && _cartridgeSectionKeys.length != _returnHeaderResponse!.data.length) {
                      _cartridgeSectionKeys.clear();
                      for (int i = 0; i < _returnHeaderResponse!.data.length; i++) {
                        _cartridgeSectionKeys.add(GlobalKey<_CartridgeSectionState>());
                        print('Created key for item ${i+1} of ${_returnHeaderResponse!.data.length}');
                      }
                    }
                    
                    // Build cartridge sections based on response data
                    if (_returnHeaderResponse?.data != null) {
                      print('Building ${_returnHeaderResponse!.data.length} cartridge sections');
                      print('Current keys: ${_cartridgeSectionKeys.length}');
                      
                      // Ensure we have the right number of keys
                      if (_cartridgeSectionKeys.length != _returnHeaderResponse!.data.length) {
                        _cartridgeSectionKeys.clear();
                        for (int i = 0; i < _returnHeaderResponse!.data.length; i++) {
                          _cartridgeSectionKeys.add(GlobalKey<_CartridgeSectionState>());
                          print('Created key for item ${i+1} of ${_returnHeaderResponse!.data.length}');
                        }
                      }
                      
                      for (int i = 0; i < _returnHeaderResponse!.data.length; i++) {
                        if (i < _cartridgeSectionKeys.length) { // Safety check
                          final data = _returnHeaderResponse!.data[i];
                          
                          // Debug the data
                          print('Data at index $i: id=${data.idTool}, code=${data.catridgeCode}, typeTrx=${data.typeCatridgeTrx}');
                          
                          // Determine section title based on typeCatridgeTrx
                          String sectionTitle;
                          final typeCatridgeTrx = data.typeCatridgeTrx?.toUpperCase() ?? 'C';
                          
                          switch (typeCatridgeTrx) {
                            case 'C':
                              sectionTitle = 'Catridge ${i + 1}';
                              break;
                            case 'D':
                              sectionTitle = 'Divert ${i + 1}';
                              break;
                            case 'P':
                              sectionTitle = 'Pocket ${i + 1}';
                              break;
                            default:
                              sectionTitle = 'Catridge ${i + 1}';
                          }
                          
                          print('Adding section: $sectionTitle for index $i');
                          
                          cartridgeSections.add(
                            Column(
                              children: [
                                CartridgeSection(
                                  key: _cartridgeSectionKeys[i],
                                  title: sectionTitle,
                                  returnData: data,
                                  parentIdToolController: _idToolController,
                                  sectionId: 'section_$i', // NEW: Add unique section ID
                                ),
                                SizedBox(height: 16), // Consistent spacing
                              ],
                            ),
                          );
                        }
                      }
                    } else {
                      // Add at least one empty cartridge section if no data
                      _cartridgeSectionKeys.clear();
                      _cartridgeSectionKeys.add(GlobalKey<_CartridgeSectionState>());
                      
                      cartridgeSections.add(
                        Column(
                          children: [
                            CartridgeSection(
                              key: _cartridgeSectionKeys[0],
                              title: 'Catridge 1',
                              returnData: null,
                              parentIdToolController: _idToolController,
                              sectionId: 'section_0', // NEW: Add unique section ID
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      );
                    }
                    
                    // Build the main content
                    Widget mainContent;
                    
                    // ID Tool and Jam Mulai fields
                    Widget idToolAndJamMulaiFields = Container(
                      margin: const EdgeInsets.only(bottom: 20), // Increased margin
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ID Tool field - larger
                          Expanded(
                            flex: 1,
                            child: _buildFormField(
                              label: 'ID Tool :',
                              controller: _idToolController,
                              enableScan: true,
                              isSmallScreen: false,
                              hintText: 'Masukkan ID Tool',
                              onIconPressed: () => _scanIdTool(),
                              onChanged: (value) {
                                // Debounce typing
                                if (_idToolTypingTimer != null) {
                                  _idToolTypingTimer!.cancel();
                                }
                                _idToolTypingTimer = Timer(const Duration(milliseconds: 500), () {
                                  // Use the direct method to fetch data by ID Tool
                                  if (value.isNotEmpty) {
                                    _fetchDataByIdTool(value);
                                  }
                                });
                              },
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Jam Mulai field - larger
                          Expanded(
                            flex: 1,
                            child: _buildFormField(
                              label: 'Jam Mulai :',
                              controller: _jamMulaiController,
                              readOnly: true,
                              hasIcon: true,
                              iconData: Icons.access_time,
                              isSmallScreen: false,
                              hintText: '--:--',
                            ),
                          ),
                        ],
                      ),
                    );
                    
                    // Wrap in SingleChildScrollView for proper scrolling
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: useRow
                          ? Column(
                              children: [
                                idToolAndJamMulaiFields,
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        children: cartridgeSections,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 4,
                                      child: DetailSection(
                                        returnData: _returnHeaderResponse,
                                        onSubmitPressed: _showTLApprovalDialog,
                                        isLandscape: false, // Consistent styling
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                idToolAndJamMulaiFields,
                                ...cartridgeSections,
                                DetailSection(
                                  returnData: _returnHeaderResponse,
                                  onSubmitPressed: _showTLApprovalDialog,
                                  isLandscape: false, // Consistent styling
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartridgeSection extends StatefulWidget {
  final String title;
  final ReturnCatridgeData? returnData;
  final TextEditingController parentIdToolController;
  final String sectionId; // NEW: Add section ID
  
  const CartridgeSection({
    Key? key, 
    required this.title, 
    this.returnData,
    required this.parentIdToolController,
    required this.sectionId, // NEW: Require section ID
  }) : super(key: key);

  @override
  State<CartridgeSection> createState() => _CartridgeSectionState();
}

class _CartridgeSectionState extends State<CartridgeSection> {
  String? kondisiSeal;
  String? kondisiCatridge;
  String wsidValue = '';

  // Modified to only have two options
  final List<String> kondisiSealOptions = ['Good', 'Bad'];
  final List<String> kondisiCatridgeOptions = ['New', 'Used'];
  
  // NEW: Getter for section ID
  String get sectionId => widget.sectionId;

  // NEW: Flag untuk mode manual (tanpa validasi scan)
  bool _isManualMode = false;

  final TextEditingController noCatridgeController = TextEditingController();
  final TextEditingController noSealController = TextEditingController();
  final TextEditingController catridgeFisikController = TextEditingController();
  final TextEditingController bagCodeController = TextEditingController();
  final TextEditingController sealCodeReturnController = TextEditingController();
  final TextEditingController branchCodeController = TextEditingController();

  // Add getters for bagCode and sealCode
  String? get bagCode => bagCodeController.text;
  String? get sealCode => sealCodeReturnController.text;
  
  // NEW: Getter untuk mengetahui apakah semua field telah di-scan
  bool get allFieldsScanned => 
    scannedFields['noCatridge'] == true &&
    scannedFields['noSeal'] == true &&
    scannedFields['bagCode'] == true &&
    scannedFields['sealCode'] == true;
  
  // NEW: Getter untuk mode validasi
  bool get isValidationComplete => _isManualMode || allFieldsScanned;

  // NEW APPROACH: Use a map to track which fields have been scanned
  Map<String, bool> scannedFields = {
    'noCatridge': false,
    'noSeal': false,
    'catridgeFisik': false,
    'bagCode': false,
    'sealCode': false,
  };

  // NEW: Method to handle barcode results from stream
  void _handleStreamBarcodeResult(String fieldKey, String barcode, String label) {
    print('🎯 CARTRIDGE [${widget.sectionId}]: Handling stream result for $fieldKey: $barcode');
    print('🎯 CARTRIDGE [${widget.sectionId}]: Current scannedFields state: $scannedFields');
    
    // Get the appropriate controller
    TextEditingController? controller = _getControllerForFieldKey(fieldKey);
    if (controller == null) {
      print('❌ CARTRIDGE [${widget.sectionId}]: No controller found for field: $fieldKey');
      return;
    }
    
    print('🎯 CARTRIDGE [${widget.sectionId}]: Controller current value: "${controller.text}"');
    
    // Validate barcode if field already has content
    if (controller.text.isNotEmpty && controller.text != barcode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ [${widget.sectionId}] Kode tidak sesuai! Expected: ${controller.text}, Scanned: $barcode'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Update the field if it's empty
    if (controller.text.isEmpty) {
      controller.text = barcode;
      print('🎯 CARTRIDGE [${widget.sectionId}]: Field updated with barcode: $barcode');
    }
    
    // CRITICAL: Only one setState call with all updates
    if (mounted) {
      setState(() {
        print('🎯 CARTRIDGE [${widget.sectionId}]: SETTING scannedFields[$fieldKey] = true');
        scannedFields[fieldKey] = true;
        
        // Update validation flags
        _updateValidationForField(fieldKey, barcode);
        
        // Pastikan field terkait ditandai sebagai valid
        if (fieldKey == 'noCatridge') {
          isNoCatridgeValid = true;
          noCatridgeError = '';
        } else if (fieldKey == 'noSeal') {
          isNoSealValid = true;
          noSealError = '';
        } else if (fieldKey == 'catridgeFisik') {
          isCatridgeFisikValid = true;
          catridgeFisikError = '';
        } else if (fieldKey == 'bagCode') {
          isBagCodeValid = true;
          bagCodeError = '';
        } else if (fieldKey == 'sealCode') {
          isSealCodeReturnValid = true;
          sealCodeReturnError = '';
        }
        
        print('✅ CARTRIDGE [${widget.sectionId}]: $fieldKey validated with checkmark - scannedFields[$fieldKey] = ${scannedFields[fieldKey]}');
      });
      
      // Show success message AFTER setState
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ [$sectionId] $label berhasil divalidasi: $barcode'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Force rebuild untuk memastikan checkmark muncul
      Future.microtask(() {
        if (mounted) setState(() {});
      });
    }
  }
  
  // Helper method to get controller for field key
  TextEditingController? _getControllerForFieldKey(String fieldKey) {
    switch (fieldKey) {
      case 'noCatridge':
        return noCatridgeController;
      case 'noSeal':
        return noSealController;
      case 'catridgeFisik':
        return catridgeFisikController;
      case 'bagCode':
        return bagCodeController;
      case 'sealCode':
        return sealCodeReturnController;
      default:
        return null;
    }
  }
  
  // Helper method to update validation flags
  void _updateValidationForField(String fieldKey, String barcode) {
    switch (fieldKey) {
      case 'noCatridge':
        isNoCatridgeValid = true;
        noCatridgeError = '';
        break;
      case 'noSeal':
        isNoSealValid = true;
        noSealError = '';
        break;
      case 'catridgeFisik':
        isCatridgeFisikValid = true;
        catridgeFisikError = '';
        break;
      case 'bagCode':
        isBagCodeValid = true;
        bagCodeError = '';
        break;
      case 'sealCode':
        isSealCodeReturnValid = true;
        sealCodeReturnError = '';
        break;
    }
  }
  
  // Method to reset all scan states
  void _resetAllScanStates() {
    if (mounted) {
      setState(() {
        scannedFields.forEach((key, value) {
          scannedFields[key] = false;
        });
      });
    }
  }

  final Map<String, TextEditingController> denomControllers = {
    '100K': TextEditingController(),
    '75K': TextEditingController(),
    '50K': TextEditingController(),
    '20K': TextEditingController(),
    '10K': TextEditingController(),
    '5K': TextEditingController(),
    '2K': TextEditingController(),
    '1K': TextEditingController(),
  };

  // Validation state
  bool isNoCatridgeValid = true;
  bool isNoSealValid = true;
  bool isCatridgeFisikValid = true;
  bool isKondisiSealValid = true;
  bool isKondisiCatridgeValid = true;
  bool isBagCodeValid = true;
  bool isSealCodeReturnValid = true;
  bool isDenomValid = true;

  // Error messages
  String noCatridgeError = '';
  String noSealError = '';
  String catridgeFisikError = '';
  String kondisiSealError = '';
  String kondisiCatridgeError = '';
  String bagCodeError = '';
  String sealCodeReturnError = '';
  String denomError = '';

  // API service
  final ApiService _apiService = ApiService();
  bool _isValidating = false;
  bool _isLoading = false;
  
  // Data baru
  String _branchCode = '1'; // Default branch code

  @override
  void initState() {
    super.initState();
    _loadReturnData();
    _loadUserData();
    
    // Set default branch code
    branchCodeController.text = _branchCode;
    
    // Initialize scannedFields map
    scannedFields = {
      'noCatridge': false,
      'noSeal': false,
      'catridgeFisik': false,
      'bagCode': false,
      'sealCode': false,
    };
    
    // Debug log
    print('INIT: scannedFields initialized: $scannedFields');
  }

  @override
  void dispose() {
    noCatridgeController.dispose();
    noSealController.dispose();
    catridgeFisikController.dispose();
    bagCodeController.dispose();
    sealCodeReturnController.dispose();
    branchCodeController.dispose();
    for (var c in denomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
  
  // Load user data untuk mendapatkan branch code
  Future<void> _loadUserData() async {
    try {
      final authService = AuthService();
      final userData = await authService.getUserData();
      if (userData != null) {
        setState(() {
          // First try to get branchCode directly
          if (userData.containsKey('branchCode') && userData['branchCode'] != null && userData['branchCode'].toString().isNotEmpty) {
            _branchCode = userData['branchCode'].toString();
            print('CartridgeSection: Using branchCode from userData: $_branchCode');
          } 
          // Then try groupId as fallback
          else if (userData.containsKey('groupId') && userData['groupId'] != null && userData['groupId'].toString().isNotEmpty) {
            _branchCode = userData['groupId'].toString();
            print('CartridgeSection: Using groupId as branchCode: $_branchCode');
          }
          // Finally try BranchCode (different casing)
          else if (userData.containsKey('BranchCode') && userData['BranchCode'] != null && userData['BranchCode'].toString().isNotEmpty) {
            _branchCode = userData['BranchCode'].toString();
            print('CartridgeSection: Using BranchCode from userData: $_branchCode');
          }
          // Default to '1' if nothing found
          else {
            _branchCode = '1';
            print('CartridgeSection: No branch code found in userData, using default: $_branchCode');
          }
          
          branchCodeController.text = _branchCode;
        });
      }
    } catch (e) {
      print('CartridgeSection: Error loading user data: $e, using default branch code: 1');
      setState(() {
        _branchCode = '1';
        branchCodeController.text = _branchCode;
      });
    }
  }
  
  // New method to fetch data from API with provided idTool
  Future<void> fetchDataFromApi(String idTool) async {
    if (idTool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan ID Tool terlebih dahulu'))
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      
      // Reset all scanned fields flags
      scannedFields.forEach((key, value) {
        scannedFields[key] = false;
      });
    });
    
    try {
      // Ensure branchCode is numeric
      String numericBranchCode = branchCodeController.text;
      if (branchCodeController.text.isEmpty || !RegExp(r'^\d+$').hasMatch(branchCodeController.text)) {
        numericBranchCode = '1'; // Default to '1' if not numeric
        print('WARNING: Branch code is not numeric: "${branchCodeController.text}", using default: $numericBranchCode');
        branchCodeController.text = numericBranchCode;
      }
      
      // Log the request for debugging
      print('Fetching data with idTool: $idTool, branchCode: $numericBranchCode (original: ${branchCodeController.text})');
      
      // Create test URL for manual verification
      final String testUrl = 'http://10.10.0.223/LocalCRF/api/CRF/rtn/validate-and-get-replenish?idtool=$idTool&branchCode=$numericBranchCode';
      print('Test URL: $testUrl');
      
      final result = await _apiService.validateAndGetReplenishRaw(
        idTool,
        numericBranchCode,
        catridgeCode: noCatridgeController.text.isNotEmpty ? noCatridgeController.text : null,
      );
      
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          // Set WSID from atmCode
          if (result['data']['atmCode'] != null) {
            wsidValue = result['data']['atmCode'].toString();
          }
          
          // Process catridge data if available
          if (result['data']['catridges'] != null && result['data']['catridges'] is List && (result['data']['catridges'] as List).isNotEmpty) {
            final catridgeData = (result['data']['catridges'] as List).first;
            
            // Fill fields from API data
            if (catridgeData['catridgeCode'] != null || catridgeData['CatridgeCode'] != null) {
              noCatridgeController.text = catridgeData['catridgeCode'] ?? catridgeData['CatridgeCode'] ?? '';
            }
            
            if (catridgeData['catridgeSeal'] != null || catridgeData['CatridgeSeal'] != null) {
              noSealController.text = catridgeData['catridgeSeal'] ?? catridgeData['CatridgeSeal'] ?? '';
            }
            
            if (catridgeData['bagCode'] != null) {
              bagCodeController.text = catridgeData['bagCode'] ?? '';
            }
            
            if (catridgeData['sealCodeReturn'] != null) {
              sealCodeReturnController.text = catridgeData['sealCodeReturn'] ?? '';
            }
            
            // Set validation flags
            isNoCatridgeValid = noCatridgeController.text.isNotEmpty;
            isNoSealValid = noSealController.text.isNotEmpty;
            isBagCodeValid = true;
            isSealCodeReturnValid = true;
            
            // IMPORTANT: Reset all scanned fields flags
            scannedFields.forEach((key, value) {
              scannedFields[key] = false;
            });
            
            print('Scan states reset after API fetch:');
            print('Scanned fields: $scannedFields');
          } else {
            print('No catridges data found in response or empty list');
          }
        });
      } else {
        // Enhanced error handling
        String errorMessage = result['message'] ?? 'Gagal mengambil data';
        
        // Add debugging info for 404 errors
        if (errorMessage.contains('404')) {
          errorMessage += '\n\nDetail permintaan:\nURL: 10.10.0.223/LocalCRF/api/CRF/rtn/validate-and-get-replenish'
              '\nParameter: idtool=$idTool, branchCode=$numericBranchCode';
              
          print('404 Error: $errorMessage');
          
          // Show more detailed error message with test URL
          _showDetailedErrorDialog(
            title: 'Kesalahan API (404)',
            message: 'Endpoint API tidak ditemukan. Mohon periksa konfigurasi server atau parameter.',
            technicalDetails: errorMessage,
            testUrl: testUrl
          );
        } else {
          // Show more detailed error message for other errors
          _showDetailedErrorDialog(
            title: 'Kesalahan API',
            message: errorMessage,
            technicalDetails: 'Endpoint: /CRF/rtn/validate-and-get-replenish\n'
                'ID Tool: $idTool\n'
                'Branch Code: $numericBranchCode',
            testUrl: testUrl
          );
        }
      }
    } catch (e) {
      // Enhanced error dialog with technical details
      _showDetailedErrorDialog(
        title: 'Kesalahan Jaringan',
        message: 'Terjadi kesalahan saat menghubungi server. Mohon periksa koneksi internet dan coba lagi.',
        technicalDetails: e.toString(),
        testUrl: 'http://10.10.0.223/LocalCRF/api/CRF/rtn/validate-and-get-replenish?idtool=${widget.parentIdToolController.text}&branchCode=$numericBranchCode'
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Modified _fetchDataFromApi to use the parent ID Tool
  Future<void> _fetchDataFromApi() async {
    await fetchDataFromApi(widget.parentIdToolController.text);
  }

  // Helper method to show detailed error dialog with technical info
  void _showDetailedErrorDialog({
    required String title, 
    required String message,
    String? technicalDetails,
    String? testUrl
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (technicalDetails != null) ...[
                const SizedBox(height: 16),
                const Text('Informasi Teknis:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    technicalDetails,
                    style: TextStyle(fontSize: 12, fontFamily: 'Courier', color: Colors.grey[800]),
                  ),
                ),
              ],
              if (testUrl != null && testUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'URL yang dapat diuji secara manual:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    testUrl,
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          if (technicalDetails != null)
            TextButton(
              onPressed: () {
                // Copy technical details to clipboard
                Clipboard.setData(ClipboardData(text: technicalDetails));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informasi teknis disalin ke clipboard'))
                );
              },
              child: const Text('Salin Info Teknis'),
            ),
          if (testUrl != null && testUrl.isNotEmpty)
            TextButton(
              onPressed: () {
                // Would normally launch URL but requires url_launcher package
                // Instead we'll copy it to clipboard
                Clipboard.setData(ClipboardData(text: testUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL disalin ke clipboard, buka di browser untuk menguji API secara langsung'))
                );
              },
              child: const Text('Salin URL Test'),
            ),
        ],
      ),
    );
  }

  Future<void> _validateNoCatridge() async {
    setState(() {
      _isValidating = true;
      noCatridgeError = ''; // Reset error message
    });
    
    // Get the catridge code
    final catridgeCode = noCatridgeController.text;
    
    // Basic validation - ensure it's not empty
    if (catridgeCode.isEmpty) {
      setState(() {
        isNoCatridgeValid = false;
        noCatridgeError = 'Nomor Catridge tidak boleh kosong';
        _isValidating = false;
      });
      return;
    }
    
    // Try to fetch data from API if ID Tool is filled
    if (widget.parentIdToolController.text.isNotEmpty) {
      await fetchDataFromApi(widget.parentIdToolController.text);
    }
    
    // Lakukan validasi sederhana di sisi client
    setState(() {
      _isValidating = false;
      isNoCatridgeValid = true;
      noCatridgeError = '';
      // Note: We don't set scan state here - it should be set only after scanning
      // because we want it to be set only after scanning
    });
  }

  Future<void> _validateNoSeal() async {
    setState(() {
      _isValidating = true;
      noSealError = ''; // Reset error message
    });
    
    // Get the seal code
    final sealCode = noSealController.text;
    
    // Basic validation - ensure it's not empty
    if (sealCode.isEmpty) {
      setState(() {
        isNoSealValid = false;
        noSealError = 'Nomor Seal tidak boleh kosong';
        _isValidating = false;
      });
      return;
    }
    
    // Lakukan validasi sederhana di sisi client
    setState(() {
      _isValidating = false;
      isNoSealValid = true;
      noSealError = '';
      // Note: We don't set scan state here - it should be set only after scanning
      // because we want it to be set only after scanning
    });
  }

  void _validateCatridgeFisik() {
    final value = catridgeFisikController.text;
    setState(() {
      isCatridgeFisikValid = value.isNotEmpty;
      catridgeFisikError = value.isEmpty ? 'Catridge Fisik tidak boleh kosong' : '';
    });
  }

  void _validateKondisiSeal(String? value) {
    setState(() {
      kondisiSeal = value;
      isKondisiSealValid = value != null;
      kondisiSealError = value == null ? 'Pilih kondisi seal' : '';
    });
  }

  void _validateKondisiCatridge(String? value) {
    setState(() {
      kondisiCatridge = value;
      isKondisiCatridgeValid = value != null;
      kondisiCatridgeError = value == null ? 'Pilih kondisi catridge' : '';
    });
  }

  void _validateBagCode() {
    setState(() {
      isBagCodeValid = bagCodeController.text.isNotEmpty;
      bagCodeError = bagCodeController.text.isEmpty ? 'Bag Code tidak boleh kosong' : '';
    });
  }

  void _validateSealCodeReturn() {
    setState(() {
      isSealCodeReturnValid = sealCodeReturnController.text.isNotEmpty;
      sealCodeReturnError = sealCodeReturnController.text.isEmpty ? 'Seal Code Return tidak boleh kosong' : '';
    });
  }

  void _validateDenom(String key, TextEditingController controller) {
    // Validate denom input
    final value = controller.text;
    if (value.isNotEmpty) {
      try {
        int.parse(value); // Ensure it's a valid number
      } catch (e) {
        setState(() {
          isDenomValid = false;
          denomError = 'Nilai denom harus berupa angka';
        });
        return;
      }
    }
    
    setState(() {
      isDenomValid = true;
      denomError = '';
    });
    
    _calculateTotals();
  }

  void _calculateTotals() {
    int totalLembar = 0;
    int totalNominal = 0;
    
    denomControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        try {
          final count = int.parse(controller.text);
          totalLembar += count;
          
          // Calculate nominal based on denom
          int denomValue = 0;
          switch (key) {
            case '100K':
              denomValue = 100000;
              break;
            case '75K':
              denomValue = 75000;
              break;
            case '50K':
              denomValue = 50000;
              break;
            case '20K':
              denomValue = 20000;
              break;
            case '10K':
              denomValue = 10000;
              break;
            case '5K':
              denomValue = 5000;
              break;
            case '2K':
              denomValue = 2000;
              break;
            case '1K':
              denomValue = 1000;
              break;
          }
          
          totalNominal += count * denomValue;
        } catch (e) {
          // Ignore parsing errors here
        }
      }
    });
    
    // Update the totals display
    // We'll implement this in the next step
  }

  @override
  void didUpdateWidget(CartridgeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadReturnData();
  }

  void _loadReturnData() {
    print('📊 _loadReturnData() called');
    if (widget.returnData != null) {
      print('📊 Loading return data...');
      setState(() {
        _isValidating = true;
      });
      
      print('📊 Setting controller values...');
      noCatridgeController.text = widget.returnData!.catridgeCode;
      noSealController.text = widget.returnData!.catridgeSeal;
      // Clear catridgeFisik field - it will be filled by scanning
      catridgeFisikController.text = '';
      
      // If bagCode is available, use it
      if (widget.returnData!.bagCode != null) {
        bagCodeController.text = widget.returnData!.bagCode!;
      }
      
      // Set sealCodeReturn from API response
      if (widget.returnData!.sealCodeReturn != null) {
        sealCodeReturnController.text = widget.returnData!.sealCodeReturn!;
      }
      
      print('📊 Controller values set: noCatridge="${noCatridgeController.text}", noSeal="${noSealController.text}", bagCode="${bagCodeController.text}", sealCode="${sealCodeReturnController.text}"');
      
      // Reset validation state for pre-filled fields
      isNoCatridgeValid = noCatridgeController.text.isNotEmpty;
      isNoSealValid = noSealController.text.isNotEmpty;
      isCatridgeFisikValid = false; // This needs to be scanned
      isBagCodeValid = bagCodeController.text.isNotEmpty;
      isSealCodeReturnValid = sealCodeReturnController.text.isNotEmpty;
      
      print('📊 Validation flags set: isNoCatridgeValid=$isNoCatridgeValid, isNoSealValid=$isNoSealValid, isBagCodeValid=$isBagCodeValid, isSealCodeReturnValid=$isSealCodeReturnValid');
      
      // IMPORTANT: Reset all scanned fields flags because user needs to validate by scanning
      print('📊 BEFORE RESET: scannedFields = $scannedFields');
      scannedFields.forEach((key, value) {
        scannedFields[key] = false;
      });
      print('📊 AFTER RESET: scannedFields = $scannedFields');
      
      print('Scan states reset after loading data:');
      print('Scanned fields: $scannedFields');
      print('Loaded data - noCatridge: ${noCatridgeController.text}, noSeal: ${noSealController.text}, bagCode: ${bagCodeController.text}, sealCode: ${sealCodeReturnController.text}');
      
      setState(() {
        _isValidating = false;
      });
      print('📊 _loadReturnData() completed');
    } else {
      print('📊 No return data to load');
    }
  }

  // Check if all forms are valid
  bool get isFormValid {
    bool formIsValid = isNoCatridgeValid && 
           isNoSealValid && 
           isCatridgeFisikValid && 
           isKondisiSealValid && 
           isKondisiCatridgeValid && 
           isBagCodeValid && 
           isSealCodeReturnValid && 
           isDenomValid &&
           noCatridgeController.text.isNotEmpty &&
           noSealController.text.isNotEmpty &&
           catridgeFisikController.text.isNotEmpty &&
           kondisiSeal != null &&
           kondisiCatridge != null &&
           bagCodeController.text.isNotEmpty &&
           sealCodeReturnController.text.isNotEmpty;
    
    // Jika mode manual diaktifkan, tidak perlu memeriksa status scan
    if (_isManualMode) {
      return formIsValid;
    }
    
    // Jika tidak dalam mode manual, periksa juga status scan
    formIsValid = formIsValid && 
                  scannedFields['noCatridge'] == true &&
                  scannedFields['noSeal'] == true &&
                  scannedFields['bagCode'] == true &&
                  scannedFields['sealCode'] == true;
           
    // Log validation status for debugging
    if (!formIsValid) {
      print('Form validation failed. Scan status: $scannedFields');
      print('Required fields scanned: noCatridge=${scannedFields['noCatridge']}, noSeal=${scannedFields['noSeal']}, bagCode=${scannedFields['bagCode']}, sealCode=${scannedFields['sealCode']}');
    }
    
    return formIsValid;
  }

  // Add validation method for scanned codes
  bool _validateScannedCode(String scannedCode, TextEditingController controller) {
    // If controller is empty, any code is valid (first scan)
    if (controller.text.isEmpty) {
      return true;
    }
    
    // Otherwise, scanned code must match the existing value
    bool isValid = scannedCode == controller.text;
    print('Validating scanned code: $scannedCode against ${controller.text} - isValid: $isValid');
    return isValid;
  }
  
  // NEW: Streamlined barcode scanner for validation using stream approach
  Future<void> _openBarcodeScanner(String label, TextEditingController controller, String fieldKey) async {
    try {
      print('🎯 OPENING SCANNER: $label for field $fieldKey in section $sectionId');
      
      // Clean field label for display
      String cleanLabel = label.replaceAll(':', '').trim();
      
      // Navigate to barcode scanner with stream approach
      await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Scan $cleanLabel',
            fieldKey: fieldKey,
            fieldLabel: cleanLabel,
            sectionId: sectionId, // NEW: Pass section ID to scanner
            onBarcodeDetected: (String barcode) {
              // Stream will handle the result, this is just for legacy compatibility
              print('🎯 SCANNER CALLBACK: $barcode for $fieldKey in section $sectionId');
            },
          ),
        ),
      );
      
      print('🎯 SCANNER CLOSED: for $fieldKey in section $sectionId');
      
    } catch (e) {
      print('Error opening barcode scanner: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka scanner: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // REMOVED: Old scanning methods replaced with stream-based approach

  // REMOVED: _scanAndValidateField - replaced with stream approach

  @override
  Widget build(BuildContext context) {
    final bool shouldShow = widget.returnData != null || widget.title == 'Catridge 1';
    
    if (!shouldShow) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              // NEW: Toggle button untuk mode manual
              TextButton.icon(
                onPressed: _toggleManualMode,
                icon: Icon(
                  _isManualMode ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _isManualMode ? Colors.green : Colors.grey,
                  size: 18,
                ),
                label: Text(
                  'Mode Manual',
                  style: TextStyle(
                    color: _isManualMode ? Colors.green : Colors.grey,
                    fontSize: 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Hidden branch code field
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 0,
              width: 0,
              child: TextField(
                controller: branchCodeController,
                enabled: false,
              ),
            ),
          ),
          
          // Two-column layout for fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No Catridge input field
                    _buildInputField(
                      'No. Catridge',
                      noCatridgeController,
                      onEditingComplete: _validateNoCatridge,
                      isValid: isNoCatridgeValid,
                      errorText: noCatridgeError,
                      hasScanner: true,
                      isLoading: _isValidating,
                      readOnly: !_isManualMode, // Bisa diedit jika mode manual
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // No Seal input field
                    _buildInputField(
                      'No. Seal',
                      noSealController,
                      onEditingComplete: _validateNoSeal,
                      isValid: isNoSealValid,
                      errorText: noSealError,
                      hasScanner: true,
                      isLoading: _isValidating,
                      readOnly: !_isManualMode, // Bisa diedit jika mode manual
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Catridge Fisik input field
                    _buildInputField(
                      'Catridge Fisik',
                      catridgeFisikController,
                      onEditingComplete: _validateCatridgeFisik,
                      isValid: isCatridgeFisikValid,
                      errorText: catridgeFisikError,
                      isScanInput: true, // Use scan input mode for this field
                      hasScanner: true, // Add scanner
                      readOnly: !_isManualMode, // Bisa diedit jika mode manual
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Bag Code input field (replaced dropdown with text field)
                    _buildInputField(
                      'Bag Code',
                      bagCodeController,
                      onEditingComplete: _validateBagCode,
                      isValid: isBagCodeValid,
                      errorText: bagCodeError,
                      hasScanner: true, // Add scanner for bag code
                      readOnly: !_isManualMode, // Bisa diedit jika mode manual
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Seal Code Return input field (replaced dropdown with text field)
                    _buildInputField(
                      'Seal Code',
                      sealCodeReturnController,
                      onEditingComplete: _validateSealCodeReturn,
                      isValid: isSealCodeReturnValid,
                      errorText: sealCodeReturnError,
                      hasScanner: true, // Add scanner for seal code
                      readOnly: !_isManualMode, // Bisa diedit jika mode manual
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Right column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kondisi Seal dropdown
                    _buildDropdownField(
                      'Kondisi Seal',
                      kondisiSeal,
                      kondisiSealOptions,
                      (val) => _validateKondisiSeal(val),
                      isValid: isKondisiSealValid,
                      errorText: kondisiSealError,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Kondisi Catridge dropdown (reduced to two options)
                    _buildDropdownField(
                      'Kondisi Catridge',
                      kondisiCatridge,
                      kondisiCatridgeOptions,
                      (val) => _validateKondisiCatridge(val),
                      isValid: isKondisiCatridgeValid,
                      errorText: kondisiCatridgeError,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Denom fields
          const Text(
            'Denom',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          if (denomError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                denomError,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: denomControllers.entries.map((entry) {
              return SizedBox(
                width: 60,
                child: TextField(
                  controller: entry.value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 8),
                  ),
                  onEditingComplete: () => _validateDenom(entry.key, entry.value),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  // Form field with scan button
  Widget _buildInputField(
    String label,
    TextEditingController controller,
    {VoidCallback? onEditingComplete,
    bool isValid = true,
    String errorText = '',
    bool hasScanner = false,
    bool isScanInput = false, // For scan input fields
    bool isLoading = false,
    bool readOnly = false}
  ) {
    // Get screen size for responsive design
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    // Define field key based on label (for scanner identification)
    String fieldKey = '';
    if (label.contains('Catridge') && !label.contains('Fisik')) {
      fieldKey = 'noCatridge';
    } else if (label.contains('Seal') && !label.contains('Code')) {
      fieldKey = 'noSeal';
    } else if (label.contains('Fisik')) {
      fieldKey = 'catridgeFisik';
    } else if (label.contains('Bag')) {
      fieldKey = 'bagCode';
    } else if (label.contains('Seal Code')) {
      fieldKey = 'sealCode';
    }
    
    // Get current scan status
    bool isScanned = scannedFields[fieldKey] == true;
    
    return _buildFormField(
      label, 
      controller,
      isValid: isValid,
      errorText: errorText,
      readOnly: readOnly,
      onScan: hasScanner ? () {
        // Open scanner for this field
        _openBarcodeScanner(label, controller, fieldKey);
      } : null,
    );
  }
  
  // Form field with scan button
  Widget _buildFormField(
    String label, 
    TextEditingController controller, 
    {bool isValid = true, 
    String errorText = '', 
    bool readOnly = false, 
    VoidCallback? onScan,
    bool isPassword = false}
  ) {
    // Mendapatkan ukuran layar untuk responsivitas
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: isSmallScreen ? 40 : 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
          children: [
              // Label section - fixed width
            SizedBox(
              width: isSmallScreen ? 90 : 110,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
              child: Text(
                    '$label :',
                style: TextStyle(
                  fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
                  color: isValid ? Colors.black : Colors.red,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ),
              ),
              
              // Input field with underline and scan button
            Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isValid ? Colors.grey.shade400 : Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          readOnly: readOnly,
                          obscureText: isPassword,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: isValid ? Colors.black : Colors.red,
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(
                              left: isSmallScreen ? 4 : 6,
                              right: isSmallScreen ? 4 : 6,
                              bottom: isSmallScreen ? 6 : 8,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                    ),
                  ),
                      ),
                      
                      // Scan button
                      if (onScan != null)
                        Container(
                          width: isSmallScreen ? 30 : 40,
                          height: isSmallScreen ? 30 : 40,
                          margin: EdgeInsets.only(
                            left: isSmallScreen ? 4 : 6,
                            bottom: isSmallScreen ? 3 : 4,
            ),
                          child: IconButton(
                icon: Icon(
                  Icons.qr_code_scanner, 
                  color: Colors.blue,
                              size: isSmallScreen ? 20 : 24,
                ),
                            padding: EdgeInsets.zero,
                            onPressed: onScan,
                          ),
              ),
                    ],
                  ),
                ),
              ),
            ],
              ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: isSmallScreen ? 90 : 110, top: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallScreen ? 10 : 12,
              ),
            ),
          ),
      ],
    );
  }

  // NEW: Simulate successful scan for testing
  void _simulateSuccessfulScan(String fieldKey, String label) {
    if (mounted) {
      setState(() {
        print('🧪 [$sectionId] SIMULATING scan validation for $fieldKey');
        scannedFields[fieldKey] = true;
        
        // Set field-specific validation flags
        if (label.contains('No. Catridge')) {
          isNoCatridgeValid = true;
          noCatridgeError = '';
        } else if (label.contains('No. Seal')) {
          isNoSealValid = true;
          noSealError = '';
        } else if (label.contains('Bag Code')) {
          isBagCodeValid = true;
          bagCodeError = '';
        } else if (label.contains('Seal Code')) {
          isSealCodeReturnValid = true;
          sealCodeReturnError = '';
        } else if (label.contains('Catridge Fisik')) {
          isCatridgeFisikValid = true;
          catridgeFisikError = '';
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🧪 [$sectionId] $label validated (TEST)!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // Simple dropdown field with validation
  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
    {bool isValid = true,
    String errorText = ''}
  ) {
    // Mendapatkan ukuran layar untuk responsivitas
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: isSmallScreen ? 90 : 110,
              child: Text(
                '$label:',
                style: TextStyle(
                  fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
                  color: isValid ? Colors.black : Colors.red,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: value,
                hint: Text(
                  'Pilih $label',
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
                isExpanded: true,
                style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: Colors.black),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 6 : 8, 
                    horizontal: isSmallScreen ? 8 : 12
                  ),
                  isDense: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isValid ? Colors.grey : Colors.red,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                items: options.map<DropdownMenuItem<String>>((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(
                      val,
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: isSmallScreen ? 90 : 110, top: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallScreen ? 10 : 12,
              ),
            ),
          ),
      ],
    );
  }

  // Add numericBranchCode getter to fix the error
  String get numericBranchCode {
    // Ensure branchCode is numeric
    if (branchCodeController.text.isEmpty || !RegExp(r'^\d+$').hasMatch(branchCodeController.text)) {
      return '1'; // Default to '1' if not numeric
    }
    return branchCodeController.text;
  }

  // NEW: Toggle manual mode
  void _toggleManualMode() {
    setState(() {
      _isManualMode = !_isManualMode;
      if (_isManualMode) {
        // Jika mode manual diaktifkan, tandai semua field sebagai valid
        isNoCatridgeValid = noCatridgeController.text.isNotEmpty;
        isNoSealValid = noSealController.text.isNotEmpty;
        isBagCodeValid = bagCodeController.text.isNotEmpty;
        isSealCodeReturnValid = sealCodeReturnController.text.isNotEmpty;
        isCatridgeFisikValid = catridgeFisikController.text.isNotEmpty;
      } else {
        // Jika mode manual dinonaktifkan, kembalikan ke status scan
        isNoCatridgeValid = noCatridgeController.text.isNotEmpty && scannedFields['noCatridge'] == true;
        isNoSealValid = noSealController.text.isNotEmpty && scannedFields['noSeal'] == true;
        isBagCodeValid = bagCodeController.text.isNotEmpty && scannedFields['bagCode'] == true;
        isSealCodeReturnValid = sealCodeReturnController.text.isNotEmpty && scannedFields['sealCode'] == true;
        isCatridgeFisikValid = catridgeFisikController.text.isNotEmpty && scannedFields['catridgeFisik'] == true;
      }
    });
  }
}

class DetailSection extends StatelessWidget {
  final ReturnHeaderResponse? returnData;
  final VoidCallback? onSubmitPressed;
  final bool isLandscape;
  
  const DetailSection({
    Key? key, 
    this.returnData,
    this.onSubmitPressed,
    this.isLandscape = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final greenTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.green[700],
      fontSize: isLandscape ? 12 : 14,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: EdgeInsets.all(isLandscape ? 8 : 12),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail WSID',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isLandscape ? 14 : 16,
              ),
            ),
            SizedBox(height: isLandscape ? 6 : 8),
          _buildLabelValue('WSID', returnData?.header?.atmCode ?? ''),
          _buildLabelValue('Bank', returnData?.header?.codeBank ?? returnData?.header?.namaBank ?? ''),
          _buildLabelValue('Lokasi', returnData?.header?.lokasi ?? ''),
          _buildLabelValue('Jenis Mesin', returnData?.header?.jnsMesin ?? ''),
          _buildLabelValue('ATM Type', returnData?.header?.idTypeAtm ?? returnData?.header?.typeATM ?? ''),
          _buildLabelValue('Tgl. Unload', returnData?.header?.timeSTReturn ?? ''),
          const Divider(height: 24, thickness: 1),
          const Text(
            'Detail Return',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Seluruh Lembar (Denom)',
                      style: greenTextStyle,
                    ),
                    const SizedBox(height: 8),
                    ..._buildDenomFields(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Seluruh Nominal (Denom)',
                      style: greenTextStyle,
                    ),
                    const SizedBox(height: 8),
                    ..._buildNominalFields(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Text(
                'Grand Total :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Text('Rp'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: returnData != null ? onSubmitPressed : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Submit Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDenomFields() {
    final denomLabels = ['100K', '75K', '50K', '20K', '10K', '5K', '2K', '1K'];
    return denomLabels
        .map(
          (label) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      // Use underlined style for consistency
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Lembar'),
              ],
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildNominalFields() {
    final denomLabels = ['100K', '75K', '50K', '20K', '10K', '5K', '2K', '1K'];
    return denomLabels
        .map(
          (label) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(': Rp'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      // Use underlined style for consistency
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}



