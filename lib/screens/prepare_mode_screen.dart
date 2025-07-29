import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prepare_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../widgets/qr_code_generator_widget.dart';
import 'dart:async';

class PrepareModePage extends StatefulWidget {
  const PrepareModePage({Key? key}) : super(key: key);

  @override
  State<PrepareModePage> createState() => _PrepareModePageState();
}

class _PrepareModePageState extends State<PrepareModePage> {
  final TextEditingController _idCRFController = TextEditingController();
  final TextEditingController _jamMulaiController = TextEditingController();
  
  // API service
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  // Data from API
  ATMPrepareReplenishData? _prepareData;
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Dynamic list of catridge controllers
  List<List<TextEditingController>> _catridgeControllers = [];
  
  // Denom values for each catridge
  List<int> _denomValues = [];
  
  // Catridge data from lookup
  List<CatridgeData?> _catridgeData = [];
  
  // Detail catridge data for the right panel
  List<DetailCatridgeItem> _detailCatridgeItems = [];

  // Divert controllers
  final List<TextEditingController> _divertControllers = [
    TextEditingController(), // No Catridge
    TextEditingController(), // Seal Catridge
    TextEditingController(), // Bag Code
    TextEditingController(), // Seal Code
    TextEditingController(), // Seal Code Return
  ];

  // Pocket controllers
  final List<TextEditingController> _pocketControllers = [
    TextEditingController(), // No Catridge
    TextEditingController(), // Seal Catridge
    TextEditingController(), // Bag Code
    TextEditingController(), // Seal Code
    TextEditingController(), // Seal Code Return
  ];

  // Divert and Pocket data
  CatridgeData? _divertCatridgeData;
  CatridgeData? _pocketCatridgeData;
  DetailCatridgeItem? _divertDetailItem;
  DetailCatridgeItem? _pocketDetailItem;
  
  // Approval form state
  bool _showApprovalForm = false;
  bool _isSubmitting = false;
  final TextEditingController _nikTLController = TextEditingController();
  final TextEditingController _passwordTLController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Initialize with one empty catridge
    _initializeCatridgeControllers(1);
    
    // Set current time as jam mulai
    _setCurrentTime();
    
    // Add listeners to text fields to auto-hide approval form
    _idCRFController.addListener(_checkAndHideApprovalForm);
    _jamMulaiController.addListener(_checkAndHideApprovalForm);
  }

  @override
  void dispose() {
    _idCRFController.dispose();
    _jamMulaiController.dispose();
    
    // Dispose all dynamic controllers
    for (var controllerList in _catridgeControllers) {
      for (var controller in controllerList) {
        controller.dispose();
      }
    }
    
    // Dispose approval form controllers
    _nikTLController.dispose();
    _passwordTLController.dispose();
    
    super.dispose();
  }
  
  // Set current time
  void _setCurrentTime() {
    final now = DateTime.now();
    _jamMulaiController.text = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // Initialize catridge controllers for the given count
  void _initializeCatridgeControllers(int count) {
    setState(() {
      // Clear existing controllers - dispose first to prevent memory leaks
      for (var controllerList in _catridgeControllers) {
        for (var controller in controllerList) {
          controller.dispose();
        }
      }
      
      // Create new list of controllers
      _catridgeControllers = List.generate(
        count,
        (_) => List.generate(
          5, // Each catridge has 5 controllers
          (_) => TextEditingController(),
        ),
      );
      
      // Add listeners to all catridge controllers
      for (int i = 0; i < _catridgeControllers.length; i++) {
        for (var controller in _catridgeControllers[i]) {
          controller.addListener(_checkAndHideApprovalForm);
        }
      }
      
      // Initialize denom values array - one per catridge
      _denomValues = List.generate(count, (_) => 0);
      
      // Initialize catridge data array - one per catridge
      _catridgeData = List.generate(count, (_) => null);
      
      // Clear detail items for consistency
      _detailCatridgeItems = [];
      
      print('Initialized $count catridge controllers and data arrays');
    });
  }
  
  // Clear all data and hide approval form
  void _clearAllData() {
    setState(() {
      // Clear controllers
      _idCRFController.clear();
      _jamMulaiController.clear();
      
      // Clear catridge controllers
      for (var controllerList in _catridgeControllers) {
        for (var controller in controllerList) {
          controller.clear();
        }
      }
      
      // Clear data
      _prepareData = null;
      _detailCatridgeItems.clear();
      _catridgeData.clear();
      _denomValues.clear();
      _errorMessage = '';
      
      // Hide approval form
      _showApprovalForm = false;
      _nikTLController.clear();
      _passwordTLController.clear();
    });
    
    // Reset time to current time
    _setCurrentTime();
  }
  
  // Check if any left side field is empty
  bool _hasAnyLeftFieldEmpty() {
    // Check header fields
    if (_idCRFController.text.trim().isEmpty) return true;
    if (_jamMulaiController.text.trim().isEmpty) return true;
    
    // Check all catridge fields
    for (var controllerList in _catridgeControllers) {
      for (var controller in controllerList) {
        if (controller.text.trim().isEmpty) return true;
      }
    }
    
    // Check if there's no prepare data
    if (_prepareData == null) return true;
    
    // Check if there are no detail catridge items
    if (_detailCatridgeItems.isEmpty) return true;
    
    return false;
  }
  
  // Auto-hide approval form if any left field is empty
  void _checkAndHideApprovalForm() {
    if (_showApprovalForm && _hasAnyLeftFieldEmpty()) {
      setState(() {
        _showApprovalForm = false;
        _nikTLController.clear();
        _passwordTLController.clear();
      });
    }
  }
  
  // Step 1: Lookup catridge and create initial detail item
  Future<void> _lookupCatridgeAndCreateDetail(int catridgeIndex, String catridgeCode) async {
    if (catridgeCode.isEmpty || !mounted) return;
    
    try {
      print('=== STEP 1: LOOKUP CATRIDGE ===');
      print('Catridge Index: $catridgeIndex');
      print('Catridge Code: $catridgeCode');
      
      // Get branch code
      String branchCode = "1"; // Default
      if (_prepareData != null && _prepareData!.branchCode.isNotEmpty) {
        branchCode = _prepareData!.branchCode;
      }
      
      // Get required standValue from prepare data for validation
      int? requiredStandValue = _prepareData?.standValue;
      
      // Get list of existing catridge codes
      List<String> existingCatridges = [];
      for (var item in _detailCatridgeItems) {
        if (item.noCatridge.isNotEmpty) {
          existingCatridges.add(item.noCatridge);
        }
      }
      if (_divertDetailItem?.noCatridge.isNotEmpty == true) {
        existingCatridges.add(_divertDetailItem!.noCatridge);
      }
      if (_pocketDetailItem?.noCatridge.isNotEmpty == true) {
        existingCatridges.add(_pocketDetailItem!.noCatridge);
      }
      
      // Remove the current catridge from existing list if we're updating
      if (_catridgeControllers.length > catridgeIndex && 
          _catridgeControllers[catridgeIndex][0].text.isNotEmpty &&
          existingCatridges.contains(_catridgeControllers[catridgeIndex][0].text)) {
        existingCatridges.remove(_catridgeControllers[catridgeIndex][0].text);
      }
      
      print('Using requiredStandValue for validation: $requiredStandValue');
      print('Using branchCode: $branchCode');
      print('Existing catridges: $existingCatridges');
      
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // API call to get catridge details with comprehensive validation
      final response = await _apiService.getCatridgeDetails(
        branchCode, 
        catridgeCode, 
        requiredStandValue: requiredStandValue,
        requiredType: 'C', // Main catridge must be type C
        existingCatridges: existingCatridges,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      print('Catridge lookup response: ${response.success}, message: ${response.message}');
      
      if (response.success && response.data != null && response.data is List && response.data.length > 0 && mounted) {
        print('Found ${response.data.length} catridges');
        
        // Get the first item from the list
        final catridgeDataJson = response.data[0] as Map<String, dynamic>;
        print('First catridge data: $catridgeDataJson');
        
        // Create a CatridgeData object from the JSON
        final catridgeData = CatridgeData.fromJson(catridgeDataJson);
        print('Parsed catridge: Code=${catridgeData.code}, StandValue=${catridgeData.standValue}');
        
        // Calculate denom amount
        String tipeDenom = _prepareData?.tipeDenom ?? 'A50';
        int denomAmount = 0;
        String denomText = '';
        
        if (tipeDenom == 'A50') {
          denomAmount = 50000;
          denomText = 'Rp 50.000';
        } else if (tipeDenom == 'A100') {
          denomAmount = 100000;
          denomText = 'Rp 100.000';
        } else {
          denomAmount = 50000;
          denomText = 'Rp 50.000';
        }
        
        // Use standValue from prepare data or catridge data
        int actualStandValue = _prepareData?.standValue ?? catridgeData.standValue.round();
        
        // Calculate total
        int totalNominal = denomAmount * actualStandValue;
        String formattedTotal = _formatCurrency(totalNominal);
        
        // Auto-populate seal if available from prepare data
        String autoSeal = '';
        if (_prepareData != null && catridgeIndex == 0) {
          // For first catridge, try to use seal from prepare data
          if (_prepareData!.catridgeSeal.isNotEmpty) {
            autoSeal = _prepareData!.catridgeSeal;
            // Also populate the controller
            if (_catridgeControllers.length > catridgeIndex && _catridgeControllers[catridgeIndex].length > 1) {
              _catridgeControllers[catridgeIndex][1].text = autoSeal;
            }
          }
        }
        
        // Create initial detail item
        final detailItem = DetailCatridgeItem(
          index: catridgeIndex + 1,
          noCatridge: catridgeData.code, // Use the code from the response
          sealCatridge: autoSeal, // Auto-populated or empty
          value: actualStandValue,
          total: formattedTotal,
          denom: denomText,
        );
        
        setState(() {
          // Store catridge data for reference
          if (catridgeIndex >= 0 && catridgeIndex < _catridgeData.length) {
            _catridgeData[catridgeIndex] = catridgeData;
          } else {
            // Ensure catridgeData list is large enough
            while (_catridgeData.length <= catridgeIndex) {
              _catridgeData.add(null);
            }
            _catridgeData[catridgeIndex] = catridgeData;
          }
          
          // Update the controller with the correct code from the response
          if (_catridgeControllers.length > catridgeIndex) {
            _catridgeControllers[catridgeIndex][0].text = catridgeData.code;
          }
          
          // Check if item already exists for this index
          int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
          if (existingIndex >= 0) {
            // Update existing item but keep seal if already filled
            var existingItem = _detailCatridgeItems[existingIndex];
            _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
              index: detailItem.index,
              noCatridge: detailItem.noCatridge,
              sealCatridge: existingItem.sealCatridge.isNotEmpty ? existingItem.sealCatridge : autoSeal,
              value: detailItem.value,
              total: detailItem.total,
              denom: detailItem.denom,
            );
            print('Updated existing detail item at index $existingIndex');
          } else {
            // Add new item
            _detailCatridgeItems.add(detailItem);
            print('Added new detail item: ${detailItem.noCatridge}');
          }
          
          // Sort by index
          _detailCatridgeItems.sort((a, b) => a.index.compareTo(b.index));
          print('Total detail items now: ${_detailCatridgeItems.length}');
          
          // Update denom values array for consistency
          if (catridgeIndex >= 0 && catridgeIndex < _denomValues.length) {
            _denomValues[catridgeIndex] = actualStandValue;
          } else {
            // Ensure denomValues list is large enough
            while (_denomValues.length <= catridgeIndex) {
              _denomValues.add(0);
            }
            _denomValues[catridgeIndex] = actualStandValue;
          }
        });
        
        // Check if approval form should be hidden
        _checkAndHideApprovalForm();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Catridge found: ${catridgeData.code}')),
        );
      } else {
        // Handle API response error or empty data
        String errorMessage = 'Catridge tidak ditemukan';
        if (!response.success && response.message.isNotEmpty) {
          // Use API error message if available
          errorMessage = response.message;
        } else if (response.success && (response.data == null || (response.data is List && response.data.length == 0))) {
          // Empty data with success response (should not happen with new logic)
          errorMessage = 'Catridge tidak ditemukan atau tidak sesuai kriteria';
        }
        
        // Create error detail item
        _createErrorDetailItem(catridgeIndex, catridgeCode, errorMessage);
        
        // Check if approval form should be hidden
        _checkAndHideApprovalForm();
        
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      print('Error looking up catridge: $e');
      _createErrorDetailItem(catridgeIndex, catridgeCode, 'Error: ${e.toString()}');
      
      // Check if approval form should be hidden
      _checkAndHideApprovalForm();
      
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error looking up catridge: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Step 2: Validate seal and update detail item using comprehensive validation
  Future<void> _validateSealAndUpdateDetail(int catridgeIndex, String sealCode) async {
    if (sealCode.isEmpty || !mounted) return;
    
    try {
      print('=== STEP 2: COMPREHENSIVE SEAL VALIDATION ===');
      print('Catridge Index: $catridgeIndex');
      print('Seal Code: $sealCode');
      
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      final response = await _apiService.validateSeal(sealCode);
      
      setState(() {
        _isLoading = false;
      });
      
      print('Seal validation response: ${response.success}');
      print('Seal validation message: ${response.message}');
      
      // Extract validation status from response data
      String validationStatus = '';
      String errorMessage = '';
      String validatedSealCode = '';
      
      if (response.data != null) {
        try {
          if (response.data is Map<String, dynamic>) {
            // Try to extract values directly from the data map
            Map<String, dynamic> dataMap = response.data as Map<String, dynamic>;
            
            // Normalize keys for consistent access
            Map<String, dynamic> normalizedData = {};
            dataMap.forEach((key, value) {
              normalizedData[key.toLowerCase()] = value;
            });
            
            // Extract status with fallbacks
            if (normalizedData.containsKey('validationstatus')) {
              validationStatus = normalizedData['validationstatus'].toString();
            } else if (normalizedData.containsKey('status')) {
              validationStatus = normalizedData['status'].toString();
            }
            
            // Extract error message with fallbacks
            if (normalizedData.containsKey('errormessage')) {
              errorMessage = normalizedData['errormessage'].toString();
            } else if (normalizedData.containsKey('message')) {
              errorMessage = normalizedData['message'].toString();
            }
            
            // Extract validated seal code with fallbacks
            if (normalizedData.containsKey('validatedsealcode')) {
              validatedSealCode = normalizedData['validatedsealcode'].toString();
            } else if (normalizedData.containsKey('sealcode')) {
              validatedSealCode = normalizedData['sealcode'].toString();
            } else if (normalizedData.containsKey('seal')) {
              validatedSealCode = normalizedData['seal'].toString();
            }
            
            // If validation is successful but no validated code, use input code
            if (validationStatus.toUpperCase() == 'SUCCESS' && validatedSealCode.isEmpty) {
              validatedSealCode = sealCode;
            }
          }
        } catch (e) {
          print('Error parsing validation data: $e');
        }
      }
      
      print('Extracted validation status: $validationStatus');
      print('Extracted error message: $errorMessage');
      print('Extracted validated seal code: $validatedSealCode');
      
      // If no status extracted, determine from overall response
      if (validationStatus.isEmpty) {
        validationStatus = response.success ? 'SUCCESS' : 'FAILED';
      }
      
      // If no error message extracted, use response message
      if (errorMessage.isEmpty && !response.success) {
        errorMessage = response.message;
      }
      
      // If still no validated code and validation successful, use input code
      if (validatedSealCode.isEmpty && validationStatus.toUpperCase() == 'SUCCESS') {
        validatedSealCode = sealCode;
      }
      
      if ((response.success && validationStatus.toUpperCase() == 'SUCCESS') && mounted) {
        // Validation successful - update with validated seal code
        setState(() {
          int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
          if (existingIndex >= 0) {
            var existingItem = _detailCatridgeItems[existingIndex];
            _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
              index: existingItem.index,
              noCatridge: existingItem.noCatridge,
              sealCatridge: validatedSealCode, // Use validated seal code
              value: existingItem.value,
              total: existingItem.total,
              denom: existingItem.denom,
            );
            print('Updated seal for detail item at index $existingIndex with validated code: $validatedSealCode');
          }
        });
        
        // Check if approval form should be hidden
        _checkAndHideApprovalForm();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seal berhasil divalidasi'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Validation failed - update detail item with error from SP
        if (errorMessage.isEmpty) {
          errorMessage = 'Seal tidak valid';
        }
        
        setState(() {
          int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
          if (existingIndex >= 0) {
            var existingItem = _detailCatridgeItems[existingIndex];
            _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
              index: existingItem.index,
              noCatridge: existingItem.noCatridge,
              sealCatridge: 'Error: $errorMessage', // Show error from SP
              value: existingItem.value,
              total: existingItem.total,
              denom: existingItem.denom,
            );
          }
        });
        
        // Check if approval form should be hidden
        _checkAndHideApprovalForm();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validasi seal gagal: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      print('Error validating seal: $e');
      // Update detail item with network/system error
      setState(() {
        int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
        if (existingIndex >= 0) {
          var existingItem = _detailCatridgeItems[existingIndex];
          _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
            index: existingItem.index,
            noCatridge: existingItem.noCatridge,
            sealCatridge: 'Error: ${e.toString()}', // Show system error
            value: existingItem.value,
            total: existingItem.total,
            denom: existingItem.denom,
          );
        }
      });
      
      // Check if approval form should be hidden
      _checkAndHideApprovalForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kesalahan sistem: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Helper method to create error detail item
  void _createErrorDetailItem(int catridgeIndex, String catridgeCode, String errorMessage) {
    final detailItem = DetailCatridgeItem(
      index: catridgeIndex + 1,
      noCatridge: catridgeCode.isNotEmpty ? catridgeCode : 'Error',
      sealCatridge: '',
      value: 0,
      total: errorMessage, // Show error in total field
      denom: '',
    );
    
    setState(() {
      int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
      if (existingIndex >= 0) {
        _detailCatridgeItems[existingIndex] = detailItem;
      } else {
        _detailCatridgeItems.add(detailItem);
      }
      
      _detailCatridgeItems.sort((a, b) => a.index.compareTo(b.index));
      print('Created error detail item: $errorMessage');
    });
    
    // Check if approval form should be hidden
    _checkAndHideApprovalForm();
  }
  
  // Remove detail catridge item
  void _removeDetailCatridgeItem(int index) {
    setState(() {
      _detailCatridgeItems.removeWhere((item) => item.index == index);
    });
    
    // Check if approval form should be hidden
    _checkAndHideApprovalForm();
  }
  
  // Check if all detail catridge items are valid and complete
  bool _areAllCatridgeItemsValid() {
    if (_detailCatridgeItems.isEmpty) return false;
    
    for (var item in _detailCatridgeItems) {
      // Check if item has error
      if (item.total.contains('Error') || item.total.contains('tidak ditemukan') ||
          item.sealCatridge.contains('Error') || item.sealCatridge.contains('tidak valid')) {
        print('Item has error: ${item.noCatridge}');
        return false;
      }
      
      // Check if all required fields are filled
      if (item.noCatridge.isEmpty || item.sealCatridge.isEmpty || item.value <= 0) {
        print('Item is incomplete: noCatridge=${item.noCatridge.isEmpty}, sealCatridge=${item.sealCatridge.isEmpty}, value=${item.value}');
        return false;
      }
    }
    
    return true;
  }
  
  // Show approval form
  void _showApprovalFormDialog() {
    setState(() {
      _showApprovalForm = true;
    });
  }
  
  // Hide approval form
  void _hideApprovalForm() {
    setState(() {
      _showApprovalForm = false;
      _nikTLController.clear();
      _passwordTLController.clear();
    });
  }
  
  // Submit data with approval
  Future<void> _submitDataWithApproval() async {
    if (_nikTLController.text.isEmpty || _passwordTLController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NIK TL SPV dan Password harus diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Step 0: Validate TL Supervisor credentials and role
      print('=== STEP 0: VALIDATE TL SUPERVISOR ===');
      final tlValidationResponse = await _apiService.validateTLSupervisor(
        nik: _nikTLController.text.trim(),
        password: _passwordTLController.text.trim(),
      );
      
      if (!tlValidationResponse.success || 
          tlValidationResponse.data?.validationStatus != 'SUCCESS') {
        throw Exception('Validasi TL SPV gagal: ${tlValidationResponse.message}');
      }
      
      print('TL Supervisor validation success: ${tlValidationResponse.data?.userName} (${tlValidationResponse.data?.userRole})');
      
      // Step 1: Update Planning API
      print('=== STEP 1: UPDATE PLANNING ===');
      final planningResponse = await _apiService.updatePlanning(
        idTool: _prepareData!.id,
        cashierCode: 'CURRENT_USER', // TODO: Get from auth service
        spvTLCode: _nikTLController.text,
        tableCode: _prepareData!.tableCode,
      );
      
      if (!planningResponse.success) {
        throw Exception('Planning update failed: ${planningResponse.message}');
      }
      
      print('Planning update success: ${planningResponse.message}');
      
      // Step 2: Insert ATM Catridge for each detail item
      print('=== STEP 2: INSERT ATM CATRIDGE ===');
      List<String> successMessages = [];
      List<String> errorMessages = [];
      
      // Function to insert catridge with type
      Future<void> insertCatridge({
        required String noCatridge,
        required String sealCatridge,
        required String bagCode,
        required String sealCode,
        required String sealReturn,
        required String typeCatridgeTrx,
        required String section,
      }) async {
        try {
          // Get current user data for userInput
          String userInput = 'UNKNOWN';
          try {
            final userData = await _authService.getUserData();
            if (userData != null) {
              userInput = userData['nik'] ?? userData['username'] ?? userData['userCode'] ?? 'UNKNOWN';
            }
          } catch (e) {
            print('Error getting user data: $e');
            userInput = 'UNKNOWN';
          }
          
          // Ensure denomination code is not empty
          String finalDenomCode = _prepareData!.denomCode;
          if (finalDenomCode.isEmpty) finalDenomCode = 'TEST';
          
          print('Inserting catridge with following data:');
          print('  ID Tool: ${_prepareData!.id}');
          print('  Bag Code: $bagCode');
          print('  Catridge Code: $noCatridge');
          print('  Seal Code: $sealCode');
          print('  Catridge Seal: $sealCatridge');
          print('  Denom Code: $finalDenomCode');
          print('  User Input: $userInput');
          print('  Seal Return: $sealReturn');
          print('  Type Catridge Trx: $typeCatridgeTrx');
          
          // Add retry logic for InsertedId errors
          int maxRetries = 2;
          for (int retry = 0; retry <= maxRetries; retry++) {
            try {
              final catridgeResponse = await _apiService.insertAtmCatridge(
                idTool: _prepareData!.id,
                bagCode: bagCode.isEmpty ? 'TEST' : bagCode,
                catridgeCode: noCatridge,
                sealCode: sealCode.isEmpty ? 'TEST' : sealCode,
                catridgeSeal: sealCatridge.isEmpty ? 'TEST' : sealCatridge,
                denomCode: finalDenomCode,
                qty: '1',
                userInput: userInput,
                sealReturn: sealReturn,
                typeCatridgeTrx: typeCatridgeTrx,
              );
              
              if (catridgeResponse.success) {
                successMessages.add('$section: ${catridgeResponse.message}');
                print('$section success: ${catridgeResponse.message}');
                break; // Exit retry loop on success
              } else {
                if (retry < maxRetries && 
                    catridgeResponse.message.contains('InsertedId') && 
                    catridgeResponse.message.contains('not belong to table')) {
                  // This is the specific error we're trying to handle with retries
                  print('$section got InsertedId error, retrying (${retry + 1}/$maxRetries)...');
                  await Future.delayed(Duration(milliseconds: 500)); // Small delay before retry
                  continue; // Try again
                }
                
                // If we've exhausted retries or it's a different error, add to errors
                errorMessages.add('$section: ${catridgeResponse.message}');
                print('$section error: ${catridgeResponse.message} (Status: ${catridgeResponse.status})');
                
                // Add the catridge to the failed list so we can show it to the user
                setState(() {
                  _failedCatridges.add(noCatridge);
                });
                break; // Exit retry loop on non-retryable error
              }
            } catch (e) {
              if (retry < maxRetries && e.toString().contains('InsertedId') && e.toString().contains('not belong to table')) {
                // Handle exception containing the specific error
                print('$section got InsertedId exception, retrying (${retry + 1}/$maxRetries)...');
                await Future.delayed(Duration(milliseconds: 500)); // Small delay before retry
                continue; // Try again
              }
              
              // If we've exhausted retries or it's a different error, add to errors
              errorMessages.add('$section: ${e.toString()}');
              print('$section exception: $e');
              
              // Add the catridge to the failed list so we can show it to the user
              setState(() {
                _failedCatridges.add(noCatridge);
              });
              break; // Exit retry loop on non-retryable exception
            }
          }
        } catch (e) {
          errorMessages.add('$section: ${e.toString()}');
          print('$section outer exception: $e');
          
          // Add the catridge to the failed list so we can show it to the user
          setState(() {
            _failedCatridges.add(noCatridge);
          });
        }
      }
      
      // Reset failed catridges list
      setState(() {
        _failedCatridges = [];
      });
      
      // First, validate that we have at least one catridge to insert
      if (_detailCatridgeItems.isEmpty) {
        throw Exception('Tidak ada data catridge untuk disimpan');
      }
      
      // Now process each catridge
      for (int i = 0; i < _detailCatridgeItems.length; i++) {
        var item = _detailCatridgeItems[i];
        print('Processing catridge ${i + 1}: ${item.noCatridge}');
        
        // Validate that the catridge code is not empty
        if (item.noCatridge.isEmpty) {
          errorMessages.add('Catridge ${i + 1}: Kode catridge tidak boleh kosong');
          print('Catridge ${i + 1} error: Kode catridge is empty');
          continue; // Skip this catridge and continue to next
        }
        
        // Get data from form fields for this catridge
        String bagCode = '';
        String sealCode = '';
        String sealReturn = '';
        
        // Get data from controllers if available
        if (i < _catridgeControllers.length) {
          bagCode = _catridgeControllers[i][2].text.trim(); // Bag Code field
          sealCode = _catridgeControllers[i][3].text.trim(); // Seal Code field
          sealReturn = _catridgeControllers[i][4].text.trim(); // Seal Code Return field
        }
        
        // Fallback to prepare data if form fields are empty
        if (bagCode.isEmpty) bagCode = _prepareData!.bagCode;
        if (sealCode.isEmpty) sealCode = _prepareData!.sealCode;
        // sealReturn MUST come from form field only - no fallback to TEST
        
        // Final validation - ensure no empty critical fields
        if (bagCode.isEmpty) bagCode = 'TEST';
        if (sealCode.isEmpty) sealCode = 'TEST';
        // Do NOT set sealReturn to TEST - it must be from form field only
        
        // Validate required fields before API call
        if (sealReturn.isEmpty) {
          errorMessages.add('Catridge ${i + 1}: Seal Code Return harus diisi');
          print('Catridge ${i + 1} error: Seal Code Return is empty');
          
          // Add the catridge to the failed list so we can show it to the user
          setState(() {
            _failedCatridges.add(item.noCatridge);
          });
          
          continue; // Skip this catridge and continue to next
        }
        
        // Insert main catridge with type C
        await insertCatridge(
          noCatridge: item.noCatridge,
          sealCatridge: item.sealCatridge,
          bagCode: bagCode,
          sealCode: sealCode,
          sealReturn: sealReturn,
          typeCatridgeTrx: 'C',
          section: 'Catridge ${i + 1}',
        );
      }
      
      // Insert Divert catridge if exists
      if (_divertDetailItem != null) {
        String sealReturn = _divertControllers[4].text.trim();
        if (sealReturn.isNotEmpty) {
          await insertCatridge(
            noCatridge: _divertDetailItem!.noCatridge,
            sealCatridge: _divertDetailItem!.sealCatridge,
            bagCode: _divertControllers[2].text.trim(),
            sealCode: _divertControllers[3].text.trim(),
            sealReturn: sealReturn,
            typeCatridgeTrx: 'D',
            section: 'Divert',
          );
        } else {
          print('Divert error: Seal Return is empty');
          // Add the catridge to the failed list so we can show it to the user
          setState(() {
            _failedCatridges.add(_divertDetailItem!.noCatridge);
          });
        }
      }

      // Insert Pocket catridge if exists
      if (_pocketDetailItem != null) {
        String sealReturn = _pocketControllers[4].text.trim();
        if (sealReturn.isNotEmpty) {
          await insertCatridge(
            noCatridge: _pocketDetailItem!.noCatridge,
            sealCatridge: _pocketDetailItem!.sealCatridge,
            bagCode: _pocketControllers[2].text.trim(),
            sealCode: _pocketControllers[3].text.trim(),
            sealReturn: sealReturn,
            typeCatridgeTrx: 'P',
            section: 'Pocket',
          );
        } else {
          print('Pocket error: Seal Return is empty');
          // Add the catridge to the failed list so we can show it to the user
          setState(() {
            _failedCatridges.add(_pocketDetailItem!.noCatridge);
          });
        }
      }

      // Show results
      if (errorMessages.isEmpty) {
        // All success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Semua data berhasil disimpan!\n${successMessages.join('\n')}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // Hide approval form and potentially navigate back or reset form
        _hideApprovalForm();
        
        // Navigate back
        Navigator.of(context).pop();
        
      } else if (successMessages.isEmpty) {
        // All failed
        throw Exception('Semua catridge gagal disimpan:\n${errorMessages.join('\n')}');
      } else {
        // Mixed results
        _showMixedResultsDialog(successMessages, errorMessages);
      }
      
    } catch (e) {
      print('Submit error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  // List to track failed catridges
  List<String> _failedCatridges = [];
  
  // Show dialog for mixed results
  void _showMixedResultsDialog(List<String> successMessages, List<String> errorMessages) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Hasil Penyimpanan Data'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Beberapa data berhasil disimpan, tetapi beberapa gagal.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('Berhasil disimpan (${successMessages.length}):'),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: successMessages.map((message) => 
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('✓ $message'),
                      )
                    ).toList(),
                  ),
                ),
                SizedBox(height: 15),
                Text('Gagal disimpan (${errorMessages.length}):'),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: errorMessages.map((message) => 
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('✗ $message'),
                      )
                    ).toList(),
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  'Catatan: Data yang berhasil disimpan sudah tersimpan di server. Apakah Anda ingin kembali dan mengubah data yang gagal disimpan?',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Kembali ke Form'),
              onPressed: () {
                Navigator.of(context).pop();
                _hideApprovalForm(); // Hide approval form but stay on the page
              },
            ),
            TextButton(
              child: Text('Selesai'),
              onPressed: () {
                Navigator.of(context).pop();
                _hideApprovalForm();
                Navigator.of(context).pop(); // Return to previous screen
              },
            ),
          ],
        );
      },
    );
  }
  
  // Fetch data from API based on ID CRF
  Future<void> _fetchPrepareData() async {
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
    
    final idText = _idCRFController.text.trim();
    if (idText.isEmpty) {
      _showErrorDialog('ID CRF tidak boleh kosong');
      return;
    }
    
    // Try to parse ID as integer
    int? id;
    try {
      id = int.parse(idText);
    } catch (e) {
      _showErrorDialog('ID CRF harus berupa angka');
      return;
    }
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }
    
    try {
      final response = await _apiService.getATMPrepareReplenish(id);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _prepareData = response.data;
            
            // Initialize controllers based on jmlKaset
            int kasetCount = _prepareData!.jmlKaset;
            if (kasetCount <= 0) kasetCount = 1; // Ensure at least 1 catridge
            
            _initializeCatridgeControllers(kasetCount);
            
            // Set jam mulai to current time
            _setCurrentTime();
            
            // Populate catridge fields if data is available
            if (_catridgeControllers.isNotEmpty && _prepareData!.catridgeCode.isNotEmpty) {
              _catridgeControllers[0][0].text = _prepareData!.catridgeCode;
              _catridgeControllers[0][1].text = _prepareData!.catridgeSeal;
              _catridgeControllers[0][2].text = _prepareData!.bagCode;
              _catridgeControllers[0][3].text = _prepareData!.sealCode;
            }
            
            // Note: standValue is now taken directly from _prepareData.standValue
            // No need to store in _denomValues array
            
            // Check if approval form should be hidden
            _checkAndHideApprovalForm();
          } else {
            _errorMessage = response.message;
            
            // Check if approval form should be hidden
            _checkAndHideApprovalForm();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          
          if (e.toString().contains('Session expired') || 
              e.toString().contains('Unauthorized')) {
            _handleSessionExpired();
          } else {
            // Provide more user-friendly error messages
            String errorMessage = e.toString();
            if (errorMessage.contains('Connection timeout') || errorMessage.contains('timeout')) {
              _errorMessage = 'Koneksi timeout. Silakan periksa jaringan dan coba lagi.';
            } else if (errorMessage.contains('Network error') || errorMessage.contains('Connection failed')) {
              _errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi internet dan coba lagi.';
            } else if (errorMessage.contains('Invalid data format')) {
              _errorMessage = 'Format data dari server tidak valid. Hubungi administrator sistem.';
            } else {
              // For other errors, show generic message
              _errorMessage = 'Terjadi kesalahan. Silakan coba lagi atau hubungi support jika masalah berlanjut.';
            }
          }
        });
        
        // If unauthorized, navigate back to login
        if (e.toString().contains('Unauthorized') || e.toString().contains('Session expired')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi telah berakhir. Silakan login ulang.'),
              backgroundColor: Colors.red,
            ),
          );
          
          // Clear token and navigate back
          await _authService.logout();
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    }
  }

  // Add error handling for session expired
  void _handleSessionExpired() async {
    if (mounted) {
      // Try to refresh token first
      final success = await _authService.refreshToken();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi telah berakhir. Silakan login kembali.'),
            backgroundColor: Colors.red,
          ),
        );
        await _authService.logout();
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header section with back button, title, and user info
            _buildHeader(context, isSmallScreen),
            
            // Error message if any
            if (_errorMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                color: Colors.red.shade100,
                width: double.infinity,
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ),
            
            // Loading indicator
            if (_isLoading)
              const LinearProgressIndicator(),
            
            // Main content - Changes layout based on screen size
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final availableHeight = constraints.maxHeight;
                  final useVerticalLayout = isSmallScreen || availableWidth < 800;
                  
                  return useVerticalLayout
                    ? SingleChildScrollView(
                        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: availableHeight - 32, // Account for padding
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Form header fields
                              _buildFormHeaderFields(isSmallScreen),
                              
                              SizedBox(height: isSmallScreen ? 8 : 16),
                              
                              // Left side - Catridge forms
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Dynamic catridge sections
                                  for (int i = 0; i < _catridgeControllers.length; i++)
                                    _buildCatridgeSection(i + 1, _catridgeControllers[i], _denomValues[i], isSmallScreen),

                                  // Divert section (single)
                                  _buildDivertSection(isSmallScreen),

                                  // Pocket section (single)
                                  _buildPocketSection(isSmallScreen),
                                ],
                              ),
                              
                              // Horizontal divider
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                height: 1,
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              
                              // Right side - Details
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Detail WSID section
                                  _buildDetailWSIDSection(isSmallScreen),
                                  
                                  // Detail Catridge section
                                  _buildDetailCatridgeSection(isSmallScreen),
                                  
                                  // Approval TL Supervisor form
                                  if (_showApprovalForm)
                                    _buildApprovalForm(isSmallScreen),
                                  
                                  // Grand Total and Submit button
                                  _buildTotalAndSubmitSection(isSmallScreen),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side - Catridge forms
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Form header fields
                                    _buildFormHeaderFields(isSmallScreen),
                                    
                                    // Dynamic catridge sections
                                    for (int i = 0; i < _catridgeControllers.length; i++)
                                      _buildCatridgeSection(i + 1, _catridgeControllers[i], _denomValues[i], isSmallScreen),

                                    // Divert section (single)
                                    _buildDivertSection(isSmallScreen),

                                    // Pocket section (single)
                                    _buildPocketSection(isSmallScreen),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Vertical divider
                          Container(
                            width: 1,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          
                          // Right side - Details
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Detail WSID section
                                    _buildDetailWSIDSection(isSmallScreen),
                                    
                                    // Detail Catridge section
                                    _buildDetailCatridgeSection(isSmallScreen),
                                    
                                    // Approval TL Supervisor form
                                    if (_showApprovalForm)
                                      _buildApprovalForm(isSmallScreen),
                                    
                                    // Grand Total and Submit button
                                    _buildTotalAndSubmitSection(isSmallScreen),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                }
              ),
            ),
            
            // Footer
            _buildFooter(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8.0 : 16.0, 
        vertical: isSmallScreen ? 4.0 : 8.0
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(
              Icons.arrow_back, 
              color: Colors.red, 
              size: isSmallScreen ? 20 : 30
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isSmallScreen ? 32 : 48),
            onPressed: () => Navigator.of(context).pop(),
          ),
          
          SizedBox(width: isSmallScreen ? 4 : 8),
          
          // Title
          Text(
            'Prepare Mode',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // Location and user info - For small screens, show minimal info
          if (isSmallScreen)
            // Compact header for small screens
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'JAKARTA-CIDENG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Meja: 010101',
                      style: TextStyle(fontSize: 8),
                    ),
                    SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'CRF_OPR',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // Full header for larger screens
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'JAKARTA-CIDENG',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Meja : 010101',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CRF_OPR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          
          SizedBox(width: isSmallScreen ? 4 : 16),
          
          // User avatar and info - Simplified for small screens
          if (isSmallScreen)
            // Just show avatar for small screens
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: const AssetImage('assets/images/user.jpg'),
              onBackgroundImageError: (exception, stackTrace) {},
            )
          else
            // Full user info for larger screens
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: const AssetImage('assets/images/user.jpg'),
                    onBackgroundImageError: (exception, stackTrace) {},
                  ),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lorenzo Putra',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '9180812021',
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
    );
  }

  Widget _buildFormHeaderFields(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8.0 : 16.0),
      child: isSmallScreen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ID CRF field - removed search button
                _buildFormField(
                  label: 'ID CRF :',
                  controller: _idCRFController,
                  hasIcon: false,
                  isSmallScreen: isSmallScreen,
                  enableScan: true,
                ),
                
                const SizedBox(height: 8),
                
                // Jam Mulai field with time icon
                _buildFormField(
                  label: 'Jam Mulai :',
                  controller: _jamMulaiController,
                  hasIcon: true,
                  iconData: Icons.access_time,
                  isSmallScreen: isSmallScreen,
                ),
                
                const SizedBox(height: 8),
                
                // Tanggal Replenish field (disabled/read-only)
                _buildFormField(
                  label: 'Tanggal Replenish :',
                  readOnly: true,
                  hintText: '―',
                  isSmallScreen: isSmallScreen,
                ),
              ],
            )
          : Row(
              children: [
                // ID CRF field - removed search button
                Expanded(
                  child: _buildFormField(
                    label: 'ID CRF :',
                    controller: _idCRFController,
                    hasIcon: false,
                    isSmallScreen: isSmallScreen,
                    enableScan: true,
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Jam Mulai field with time icon
                Expanded(
                  child: _buildFormField(
                    label: 'Jam Mulai :',
                    controller: _jamMulaiController,
                    hasIcon: true,
                    iconData: Icons.access_time,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Tanggal Replenish field (disabled/read-only)
                Expanded(
                  child: _buildFormField(
                    label: 'Tanggal Replenish :',
                    readOnly: true,
                    hintText: '―',
                    isSmallScreen: isSmallScreen,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCatridgeSection(
    int index, 
    List<TextEditingController> controllers, 
    int denomValue,
    bool isSmallScreen
  ) {
    // Get tipeDenom from API data if available
    String? tipeDenom = _prepareData?.tipeDenom;
    int standValue = _prepareData?.standValue ?? 0;
    
    // Convert tipeDenom to rupiah value
    String denomText = '';
    int denomAmount = 0;
    
    // Only show denom values if _prepareData is available
    if (_prepareData != null && tipeDenom != null) {
      if (tipeDenom == 'A50') {
        denomText = 'Rp 50.000';
        denomAmount = 50000;
      } else if (tipeDenom == 'A100') {
        denomText = 'Rp 100.000';
        denomAmount = 100000;
      } else {
        // Default fallback
        denomText = 'Rp 50.000';
        denomAmount = 50000;
      }
    } else {
      // Empty state when no data is available
      denomText = '—';
    }
    
    // Calculate total nominal using standValue from prepare data
    String formattedTotal = '—';
    int actualValue = _prepareData?.standValue ?? 0;
    
    if (denomAmount > 0 && actualValue > 0) {
      int totalNominal = denomAmount * actualValue;
      formattedTotal = _formatCurrency(totalNominal);
    }
    
    // Determine image path based on tipeDenom
    String? imagePath;
    if (_prepareData != null && tipeDenom != null) {
      imagePath = 'assets/images/${tipeDenom}.png';
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Catridge title with Denom indicator on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  'Catridge $index',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Denom',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 8),
                    Flexible(
                      child: Text(
                        denomText,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : 15),
          
          // Fields with denom section on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - All 5 fields in single column (vertical) - made narrower
              Expanded(
                flex: isSmallScreen ? 3 : 3, // Increased from 2 to 3
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No. Catridge field
                    _buildCompactField(
                      label: 'No. Catridge', 
                      controller: controllers[0],
                      isSmallScreen: isSmallScreen,
                      catridgeIndex: index - 1,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Catridge field
                    _buildCompactField(
                      label: 'Seal Catridge', 
                      controller: controllers[1],
                      isSmallScreen: isSmallScreen,
                      catridgeIndex: index - 1,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Bag Code field
                    _buildCompactField(
                      label: 'Bag Code', 
                      controller: controllers[2],
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code field
                    _buildCompactField(
                      label: 'Seal Code', 
                      controller: controllers[3],
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code Return field
                    if (controllers.length >= 5)
                      _buildCompactField(
                        label: 'Seal Code Return', 
                        controller: controllers[4],
                        isSmallScreen: isSmallScreen,
                      ),
                  ],
                ),
              ),
              
              SizedBox(width: isSmallScreen ? 12 : 16),
              
              // Right side - Denom details with image and total - balanced width
              Expanded(
                flex: isSmallScreen ? 2 : 2, // Reduced from 2:3 to 3:2
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Money image - adjusted size
                    Container(
                      height: isSmallScreen ? 110 : 135,
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _prepareData == null || imagePath == null
                        ? Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: isSmallScreen ? 45 : 60,
                              color: Colors.grey.shade400,
                            ),
                          )
                        : Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.currency_exchange,
                                    size: isSmallScreen ? 45 : 60,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(height: isSmallScreen ? 5 : 8),
                                  Text(
                                    denomText,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 13 : 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              );
                            },
                          ),
                    ),
                    
                    // Value and Lembar info
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 9 : 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Value',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _prepareData?.standValue != null && _prepareData!.standValue > 0
                              ? _prepareData!.standValue.toString()
                              : '—',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                          Text(
                            'Lembar',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total Nominal box
                    Container(
                      margin: EdgeInsets.only(top: isSmallScreen ? 11 : 16),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 11 : 13, 
                        horizontal: isSmallScreen ? 9 : 11
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFDCF8C6),  // Light green background
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Nominal',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                            formattedTotal,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Divider at the bottom
          Padding(
            padding: EdgeInsets.only(top: isSmallScreen ? 15 : 25),
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to format currency
  String _formatCurrency(int amount) {
    String value = amount.toString();
    String result = '';
    int count = 0;
    
    for (int i = value.length - 1; i >= 0; i--) {
      count++;
      result = value[i] + result;
      if (count % 3 == 0 && i > 0) {
        result = '.$result';
      }
    }
    
    return 'Rp $result';
  }

  // Helper method to build compact field (for inline layout with underline)
  Widget _buildCompactField({
    required String label,
    required TextEditingController controller,
    required bool isSmallScreen,
    int? catridgeIndex,
    Function(String)? onCatridgeChange,
    Function(String)? onSealChange,
  }) {
    return Container(
      height: isSmallScreen ? 32 : 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Label section - fixed width
          SizedBox(
            width: isSmallScreen ? 85 : 100,
            child: Padding(
              padding: EdgeInsets.only(bottom: isSmallScreen ? 4 : 6),
              child: Text(
                '$label :',
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 12,
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
                      style: TextStyle(fontSize: isSmallScreen ? 10 : 12),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(
                          left: isSmallScreen ? 4 : 6,
                          right: isSmallScreen ? 4 : 6,
                          bottom: isSmallScreen ? 4 : 6,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (value) {
                        // Step 1: If this is a catridge code field, lookup catridge and create detail
                        if (label == 'No. Catridge') {
                          if (catridgeIndex != null) {
                            // For main catridge section
                            Future.delayed(Duration(milliseconds: 500), () {
                              if (controller.text == value && value.isNotEmpty) {
                                _lookupCatridgeAndCreateDetail(catridgeIndex, value);
                              }
                            });
                          } else if (onCatridgeChange != null) {
                            // For Divert/Pocket sections
                            Future.delayed(Duration(milliseconds: 500), () {
                              if (controller.text == value && value.isNotEmpty) {
                                onCatridgeChange(value);
                              }
                            });
                          }
                        }
                        // Step 2: If this is a seal catridge field, validate seal and update detail
                        else if (label == 'Seal Catridge') {
                          if (catridgeIndex != null) {
                            // For main catridge section
                            Future.delayed(Duration(milliseconds: 500), () {
                              if (controller.text == value && value.isNotEmpty) {
                                _validateSealAndUpdateDetail(catridgeIndex, value);
                              }
                            });
                          } else if (onSealChange != null) {
                            // For Divert/Pocket sections
                            Future.delayed(Duration(milliseconds: 500), () {
                              if (controller.text == value && value.isNotEmpty) {
                                onSealChange(value);
                              }
                            });
                          }
                        }
                      },
                    ),
                  ),
                  // Scan barcode icon button - positioned on the underline
                  Container(
                    width: isSmallScreen ? 20 : 24,
                    height: isSmallScreen ? 20 : 24,
                    margin: EdgeInsets.only(
                      left: isSmallScreen ? 4 : 6,
                      bottom: isSmallScreen ? 2 : 3,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.qr_code_scanner,
                        size: isSmallScreen ? 12 : 16,
                        color: Colors.blue.shade600,
                      ),
                      onPressed: () => _openBarcodeScanner(label, controller),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  Widget _buildDetailWSIDSection(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 15 : 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail WSID',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 15),
          
          _buildDetailRow('WSID', _prepareData?.atmCode ?? '-', isSmallScreen),
          _buildDetailRow('Bank', _prepareData?.codeBank ?? '-', isSmallScreen),
          _buildDetailRow('Lokasi', _prepareData?.lokasi ?? '-', isSmallScreen),
          _buildDetailRow('ATM Type', _prepareData?.jnsMesin ?? '-', isSmallScreen),
          _buildDetailRow('Jumlah Kaset', '${_prepareData?.jmlKaset ?? 0}', isSmallScreen),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 80 : 100,
            child: Text(
              '$label :',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailCatridgeSection(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 15 : 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Catridge Details
          Text(
            'Detail Catridge',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 15),
          
          // Display detail catridge items
          if (_detailCatridgeItems.isNotEmpty)
            ..._detailCatridgeItems.map((item) => _buildDetailCatridgeItem(item, isSmallScreen)).toList()
          else
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'No catridge data available',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
            
          // Divider between sections
          if (_divertDetailItem != null || _pocketDetailItem != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 15 : 25),
              child: Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
            ),
            
          // Divert Details if exists
          if (_divertDetailItem != null) ...[
            Text(
              'Detail Divert',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 15),
            _buildDetailCatridgeItem(_divertDetailItem!, isSmallScreen),
          ],
          
          // Divider between divert and pocket
          if (_divertDetailItem != null && _pocketDetailItem != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 15 : 25),
              child: Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
            ),
            
          // Pocket Details if exists
          if (_pocketDetailItem != null) ...[
            Text(
              'Detail Pocket',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 15),
            _buildDetailCatridgeItem(_pocketDetailItem!, isSmallScreen),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDetailCatridgeItem(DetailCatridgeItem item, bool isSmallScreen) {
    // Check if this is an error item
    bool isError = item.total.contains('Error') || item.total.contains('tidak ditemukan') || 
                   item.sealCatridge.contains('Error') || item.sealCatridge.contains('tidak valid');
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        border: Border.all(color: isError ? Colors.red.shade300 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Catridge number, Denom and trash icon
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: isError ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              border: Border(
                bottom: BorderSide(color: isError ? Colors.red.shade300 : Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${item.index}. Catridge ${item.index}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        color: isError ? Colors.red.shade700 : null,
                      ),
                    ),
                    SizedBox(width: 20),
                    if (!isError)
                      Text(
                        'Denom : ${item.denom}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: isSmallScreen ? 16 : 18,
                      ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: isSmallScreen ? 16 : 18,
                    ),
                    onPressed: () => _removeDetailCatridgeItem(item.index),
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Detail fields
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            child: Column(
              children: [
                _buildDetailItemRow('No. Catridge', item.noCatridge, isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Seal Catridge', item.sealCatridge, isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Value', item.value.toString(), isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Total', item.total, isSmallScreen, isError),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailItemRow(String label, String value, bool isSmallScreen, [bool isError = false]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isSmallScreen ? 100 : 120,
          child: Text(
            '$label :',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w500,
              color: isError ? Colors.red.shade700 : null,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: isError && (value.contains('Error') || value.contains('tidak')) 
                     ? Colors.red.shade700 : null,
              fontWeight: isError && (value.contains('Error') || value.contains('tidak'))
                        ? FontWeight.w500 : null,
            ),
          ),
        ),
      ],
    );
  }
  
  // Build Approval TL Supervisor form
  Widget _buildApprovalForm(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 15 : 25, top: isSmallScreen ? 10 : 15),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.green.shade700,
                size: isSmallScreen ? 20 : 24,
              ),
              SizedBox(width: 8),
              Text(
                'Approval TL Supervisor',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // NIK TL SPV Field
          _buildApprovalField(
            label: 'NIK TL SPV',
            controller: _nikTLController,
            isSmallScreen: isSmallScreen,
            icon: Icons.person,
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // Password Field
          _buildApprovalField(
            label: 'Password',
            controller: _passwordTLController,
            isSmallScreen: isSmallScreen,
            icon: Icons.lock,
            isPassword: true,
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // OR Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.green.shade300)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ATAU',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.green.shade300)),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // QR Code Generator Section
          QRCodeGeneratorWidget(
            action: 'PREPARE',
            idTool: _prepareData?.id?.toString() ?? _idCRFController.text,
            catridgeData: _prepareCatridgeQRData(),
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Cancel button
              TextButton(
                onPressed: _isSubmitting ? null : _hideApprovalForm,
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              
              SizedBox(width: 12),
              
              // Submit button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5AE25A), Color(0xFF29CC29)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitDataWithApproval,
                  icon: _isSubmitting 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.check, size: isSmallScreen ? 16 : 18),
                  label: Text(
                    _isSubmitting ? 'Processing...' : 'Approve & Submit',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 8 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Helper method to build approval form fields
  Widget _buildApprovalField({
    required String label,
    required TextEditingController controller,
    required bool isSmallScreen,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: isSmallScreen ? 36 : 40,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.green.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              SizedBox(width: 12),
              Icon(
                icon,
                size: isSmallScreen ? 16 : 18,
                color: Colors.green.shade600,
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isPassword,
                  enabled: !_isSubmitting,
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: isPassword ? '••••••••••' : 'Enter $label',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
            ],
          ),
        ),
      ],
    );
  }

  
  Widget _buildTotalAndSubmitSection(bool isSmallScreen) {
    // Add debugging for submit button validation
    print('=== SUBMIT BUTTON CHECK ===');
    print('_prepareData is null: ${_prepareData == null}');
    print('_detailCatridgeItems.length: ${_detailCatridgeItems.length}');
    if (_detailCatridgeItems.isNotEmpty) {
      for (int i = 0; i < _detailCatridgeItems.length; i++) {
        var item = _detailCatridgeItems[i];
        print('Item $i: ${item.noCatridge} - ${item.sealCatridge} - ${item.value} - ${item.total}');
      }
    }
    bool isValid = _areAllCatridgeItemsValid();
    print('_areAllCatridgeItemsValid(): $isValid');
    
    // Jika belum ada data, tampilkan tanda strip
    if (_prepareData == null) {
      return Padding(
        padding: EdgeInsets.only(top: isSmallScreen ? 10 : 25),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Grand Total
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Grand Total :',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 15),
                Text(
                  '—',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 0),
            
            // Submit button with arrow icon
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5AE25A), Color(0xFF29CC29)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _areAllCatridgeItemsValid() ? _showApprovalFormDialog : null,
                icon: Icon(Icons.arrow_forward, size: isSmallScreen ? 14 : 16),
                label: Text(
                  'Submit Data',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 24, 
                    vertical: isSmallScreen ? 6 : 12
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Get tipeDenom from API data if available
    String tipeDenom = _prepareData?.tipeDenom ?? 'A50';
    int standValue = _prepareData?.standValue ?? 0;
    
    // Convert tipeDenom to rupiah value
    int denomAmount = 0;
    if (tipeDenom == 'A50') {
      denomAmount = 50000;
    } else if (tipeDenom == 'A100') {
      denomAmount = 100000;
    } else {
      // Default fallback
      denomAmount = 50000;
    }
    
    // Calculate total from detail catridge items
    int totalAmount = 0;
    for (var item in _detailCatridgeItems) {
      // Parse total back to int (remove currency formatting)
      String cleanTotal = item.total.replaceAll('Rp ', '').replaceAll('.', '').trim();
      if (cleanTotal.isNotEmpty && cleanTotal != '0') {
        try {
          totalAmount += int.parse(cleanTotal);
        } catch (e) {
          // If parsing fails, calculate from value and denom
          String tipeDenom = _prepareData?.tipeDenom ?? 'A50';
          int denomAmount = tipeDenom == 'A100' ? 100000 : 50000;
          totalAmount += denomAmount * item.value;
        }
      }
    }
    
    String formattedTotal = totalAmount > 0 ? _formatCurrency(totalAmount) : '—';
    
    return Padding(
      padding: EdgeInsets.only(top: isSmallScreen ? 10 : 25),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Grand Total
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Grand Total :',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: isSmallScreen ? 6 : 15),
              Flexible(
                child: Text(
                  formattedTotal,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 8 : 0),
          
          // Submit button with arrow icon
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                colors: [Color(0xFF5AE25A), Color(0xFF29CC29)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _areAllCatridgeItemsValid() ? _showApprovalFormDialog : null,
              icon: Icon(Icons.arrow_forward, size: isSmallScreen ? 14 : 16),
              label: Text(
                'Submit Data',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 24, 
                  vertical: isSmallScreen ? 6 : 12
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFooter(bool isSmallScreen) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 4 : 10,
        horizontal: isSmallScreen ? 8 : 20,
      ),
      child: Row(
        children: [
          // Left side - version info
          Flexible(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'CASH REPLENISH FORM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 10 : 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 4 : 8),
                Text(
                  'ver. 0.0.1',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 8 : 14,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Right side - logos
          Flexible(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/advantage_logo.png',
                  height: isSmallScreen ? 20 : 40,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: isSmallScreen ? 20 : 40,
                      width: isSmallScreen ? 60 : 120,
                      color: Colors.transparent,
                      child: Center(
                        child: Text(
                          'ADVANTAGE',
                          style: TextStyle(fontSize: isSmallScreen ? 8 : 12),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(width: isSmallScreen ? 6 : 20),
                Image.asset(
                  'assets/images/crf_logo.png',
                  height: isSmallScreen ? 20 : 40,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: isSmallScreen ? 20 : 40,
                      width: isSmallScreen ? 20 : 60,
                      color: Colors.transparent,
                      child: Center(
                        child: Text(
                          'CRF',
                          style: TextStyle(fontSize: isSmallScreen ? 8 : 12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    TextEditingController? controller,
    bool readOnly = false,
    String? hintText,
    bool hasIcon = false,
    IconData iconData = Icons.search,
    VoidCallback? onIconPressed,
    required bool isSmallScreen,
    bool enableScan = false,
  }) {
    return Container(
      height: isSmallScreen ? 36 : 45,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Label section - fixed width
          SizedBox(
            width: isSmallScreen ? 100 : 120,
            child: Padding(
              padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
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
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      decoration: InputDecoration(
                        hintText: hintText,
                        contentPadding: EdgeInsets.only(
                          left: isSmallScreen ? 4 : 6,
                          right: isSmallScreen ? 4 : 6,
                          bottom: isSmallScreen ? 6 : 8,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (value) {
                        // Auto-trigger fetch data for ID CRF field
                        if (label == 'ID CRF :' && value.isNotEmpty) {
                          // Debounce the API call to avoid too many requests
                          Future.delayed(Duration(milliseconds: 800), () {
                            if (controller != null && controller.text == value && value.isNotEmpty) {
                              _fetchPrepareData();
                            }
                          });
                        }
                      },
                    ),
                  ),
                  
                  // Icons positioned on the underline
                  if (enableScan && controller != null)
                    Container(
                      width: isSmallScreen ? 20 : 24,
                      height: isSmallScreen ? 20 : 24,
                      margin: EdgeInsets.only(
                        left: isSmallScreen ? 4 : 6,
                        bottom: isSmallScreen ? 3 : 4,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code_scanner,
                          size: isSmallScreen ? 14 : 18,
                          color: Colors.blue.shade600,
                        ),
                        onPressed: () => _openBarcodeScanner(label, controller),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    
                  if (hasIcon)
                    Container(
                      width: isSmallScreen ? 20 : 24,
                      height: isSmallScreen ? 20 : 24,
                      margin: EdgeInsets.only(
                        left: isSmallScreen ? 4 : 6,
                        bottom: isSmallScreen ? 3 : 4,
                      ),
                      child: IconButton(
                        icon: Icon(
                          iconData,
                          size: isSmallScreen ? 14 : 18,
                          color: Colors.grey.shade700,
                        ),
                        onPressed: onIconPressed,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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

  // Open barcode scanner for field input
  Future<void> _openBarcodeScanner(String fieldLabel, TextEditingController controller) async {
    try {
      print('Opening barcode scanner for field: $fieldLabel');
      
      // Clean field label for display
      String cleanLabel = fieldLabel.replaceAll(' :', '').trim();
      
      // Navigate to barcode scanner
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Scan $cleanLabel',
            onBarcodeDetected: (String barcode) {
              print('Barcode detected for $cleanLabel: $barcode');
              
              // Fill the field with scanned barcode
              setState(() {
                controller.text = barcode;
              });
              
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$cleanLabel berhasil diisi: $barcode'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              
              // Trigger the same logic as manual input
              if (cleanLabel == 'ID CRF') {
                // Trigger API call to fetch prepare data
                Future.delayed(Duration(milliseconds: 300), () {
                  _fetchPrepareData();
                });
              } else if (cleanLabel == 'No. Catridge') {
                // Find catridge index for this controller
                for (int i = 0; i < _catridgeControllers.length; i++) {
                  if (_catridgeControllers[i].isNotEmpty && _catridgeControllers[i][0] == controller) {
                    Future.delayed(Duration(milliseconds: 300), () {
                      _lookupCatridgeAndCreateDetail(i, barcode);
                    });
                    break;
                  }
                }
              } else if (cleanLabel == 'Seal Catridge') {
                // Find catridge index for this controller
                for (int i = 0; i < _catridgeControllers.length; i++) {
                  if (_catridgeControllers[i].length > 1 && _catridgeControllers[i][1] == controller) {
                    Future.delayed(Duration(milliseconds: 300), () {
                      _validateSealAndUpdateDetail(i, barcode);
                    });
                    break;
                  }
                }
              }
            },
          ),
        ),
      );
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

  // Build Divert section
  Widget _buildDivertSection(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divert title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  'Divert',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : 15),
          
          // Fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - All 5 fields in single column
              Expanded(
                flex: isSmallScreen ? 3 : 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No. Catridge field
                    _buildCompactField(
                      label: 'No. Catridge', 
                      controller: _divertControllers[0],
                      isSmallScreen: isSmallScreen,
                      onCatridgeChange: (value) => _lookupDivertCatridge(value),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Catridge field
                    _buildCompactField(
                      label: 'Seal Catridge', 
                      controller: _divertControllers[1],
                      isSmallScreen: isSmallScreen,
                      onSealChange: (value) => _validateDivertSeal(value),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Bag Code field
                    _buildCompactField(
                      label: 'Bag Code', 
                      controller: _divertControllers[2],
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code field
                    _buildCompactField(
                      label: 'Seal Code', 
                      controller: _divertControllers[3],
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code Return field
                    _buildCompactField(
                      label: 'Seal Code Return', 
                      controller: _divertControllers[4],
                      isSmallScreen: isSmallScreen,
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: isSmallScreen ? 12 : 16),
              
              // Right side - Denom details
              Expanded(
                flex: isSmallScreen ? 2 : 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Money image
                    Container(
                      height: isSmallScreen ? 110 : 135,
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.currency_exchange,
                            size: isSmallScreen ? 45 : 60,
                            color: Colors.orange,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                            'Divert',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    // Value and Lembar info
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 9 : 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Value',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _divertDetailItem?.value.toString() ?? '—',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                          Text(
                            'Lembar',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total Nominal box
                    Container(
                      margin: EdgeInsets.only(top: isSmallScreen ? 11 : 16),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 11 : 13, 
                        horizontal: isSmallScreen ? 9 : 11
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFDCF8C6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Nominal',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                            _divertDetailItem?.total ?? '—',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Divider
          Padding(
            padding: EdgeInsets.only(top: isSmallScreen ? 15 : 25),
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  // Build Pocket section
  Widget _buildPocketSection(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pocket title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  'Pocket',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : 15),
          
          // Fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - All 5 fields in single column
              Expanded(
                flex: isSmallScreen ? 3 : 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No. Catridge field
                    _buildCompactField(
                      label: 'No. Catridge', 
                      controller: _pocketControllers[0],
                      isSmallScreen: isSmallScreen,
                      onCatridgeChange: (value) => _lookupPocketCatridge(value),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Catridge field
                    _buildCompactField(
                      label: 'Seal Catridge', 
                      controller: _pocketControllers[1],
                      isSmallScreen: isSmallScreen,
                      onSealChange: (value) => _validatePocketSeal(value),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Bag Code field
                    _buildCompactField(
                      label: 'Bag Code', 
                      controller: _pocketControllers[2],
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code field
                    _buildCompactField(
                      label: 'Seal Code', 
                      controller: _pocketControllers[3],
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code Return field
                    _buildCompactField(
                      label: 'Seal Code Return', 
                      controller: _pocketControllers[4],
                      isSmallScreen: isSmallScreen,
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: isSmallScreen ? 12 : 16),
              
              // Right side - Denom details
              Expanded(
                flex: isSmallScreen ? 2 : 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Money image
                    Container(
                      height: isSmallScreen ? 110 : 135,
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.currency_exchange,
                            size: isSmallScreen ? 45 : 60,
                            color: Colors.purple,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                            'Pocket',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    // Value and Lembar info
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 9 : 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Value',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _pocketDetailItem?.value.toString() ?? '—',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                          Text(
                            'Lembar',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total Nominal box
                    Container(
                      margin: EdgeInsets.only(top: isSmallScreen ? 11 : 16),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 11 : 13, 
                        horizontal: isSmallScreen ? 9 : 11
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFDCF8C6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Nominal',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                            _pocketDetailItem?.total ?? '—',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Divider
          Padding(
            padding: EdgeInsets.only(top: isSmallScreen ? 15 : 25),
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  // Lookup Divert catridge
  Future<void> _lookupDivertCatridge(String catridgeCode) async {
    if (catridgeCode.isEmpty || !mounted) return;
    
    try {
      // Get branch code
      String branchCode = "1";
      if (_prepareData != null && _prepareData!.branchCode.isNotEmpty) {
        branchCode = _prepareData!.branchCode;
      }
      
      // Get list of existing catridge codes
      List<String> existingCatridges = [];
      for (var item in _detailCatridgeItems) {
        if (item.noCatridge.isNotEmpty) {
          existingCatridges.add(item.noCatridge);
        }
      }
      if (_pocketDetailItem?.noCatridge.isNotEmpty == true) {
        existingCatridges.add(_pocketDetailItem!.noCatridge);
      }
      
      final response = await _apiService.getCatridgeDetails(
        branchCode, 
        catridgeCode,
        requiredType: 'D', // Must be type D for divert
        existingCatridges: existingCatridges,
      );
      
      if (response.success && response.data.isNotEmpty && mounted) {
        final catridgeData = response.data.first;
        
        // Calculate total
        int denomAmount = _prepareData?.tipeDenom == 'A100' ? 100000 : 50000;
        int standValueInt = catridgeData.standValue.round();
        int totalNominal = denomAmount * standValueInt;
        String formattedTotal = _formatCurrency(totalNominal);
        
        setState(() {
          _divertCatridgeData = catridgeData;
          _divertDetailItem = DetailCatridgeItem(
            index: 1,
            noCatridge: catridgeCode,
            sealCatridge: '',
            value: standValueInt,
            total: formattedTotal,
            denom: denomAmount == 100000 ? 'Rp 100.000' : 'Rp 50.000',
          );
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Divert catridge found: ${catridgeData.code}')),
        );
      } else {
        setState(() {
          _divertCatridgeData = null;
          _divertDetailItem = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _divertCatridgeData = null;
        _divertDetailItem = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Validate Divert seal
  Future<void> _validateDivertSeal(String sealCode) async {
    if (sealCode.isEmpty || !mounted) return;
    
    try {
      final response = await _apiService.validateSeal(sealCode);
      
      if (response.success && response.data != null && 
          response.data!.validationStatus == 'SUCCESS' && mounted) {
        setState(() {
          if (_divertDetailItem != null) {
            _divertDetailItem = DetailCatridgeItem(
              index: _divertDetailItem!.index,
              noCatridge: _divertDetailItem!.noCatridge,
              sealCatridge: response.data!.validatedSealCode,
              value: _divertDetailItem!.value,
              total: _divertDetailItem!.total,
              denom: _divertDetailItem!.denom,
            );
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seal berhasil divalidasi'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Lookup Pocket catridge
  Future<void> _lookupPocketCatridge(String catridgeCode) async {
    if (catridgeCode.isEmpty || !mounted) return;
    
    try {
      // Get branch code
      String branchCode = "1";
      if (_prepareData != null && _prepareData!.branchCode.isNotEmpty) {
        branchCode = _prepareData!.branchCode;
      }
      
      // Get list of existing catridge codes
      List<String> existingCatridges = [];
      for (var item in _detailCatridgeItems) {
        if (item.noCatridge.isNotEmpty) {
          existingCatridges.add(item.noCatridge);
        }
      }
      if (_divertDetailItem?.noCatridge.isNotEmpty == true) {
        existingCatridges.add(_divertDetailItem!.noCatridge);
      }
      
      final response = await _apiService.getCatridgeDetails(
        branchCode, 
        catridgeCode,
        requiredType: 'P', // Must be type P for pocket
        existingCatridges: existingCatridges,
      );
      
      if (response.success && response.data.isNotEmpty && mounted) {
        final catridgeData = response.data.first;
        
        // Calculate total
        int denomAmount = _prepareData?.tipeDenom == 'A100' ? 100000 : 50000;
        int standValueInt = catridgeData.standValue.round();
        int totalNominal = denomAmount * standValueInt;
        String formattedTotal = _formatCurrency(totalNominal);
        
        setState(() {
          _pocketCatridgeData = catridgeData;
          _pocketDetailItem = DetailCatridgeItem(
            index: 1,
            noCatridge: catridgeCode,
            sealCatridge: '',
            value: standValueInt,
            total: formattedTotal,
            denom: denomAmount == 100000 ? 'Rp 100.000' : 'Rp 50.000',
          );
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pocket catridge found: ${catridgeData.code}')),
        );
      } else {
        setState(() {
          _pocketCatridgeData = null;
          _pocketDetailItem = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _pocketCatridgeData = null;
        _pocketDetailItem = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _validatePocketSeal(String sealCode) async {
    if (sealCode.isEmpty || !mounted) return;
    
    try {
      final response = await _apiService.validateSeal(sealCode);
      
      if (response.success && response.data != null && 
          response.data!.validationStatus == 'SUCCESS' && mounted) {
        setState(() {
          if (_pocketDetailItem != null) {
            _pocketDetailItem = DetailCatridgeItem(
              index: _pocketDetailItem!.index,
              noCatridge: _pocketDetailItem!.noCatridge,
              sealCatridge: response.data!.validatedSealCode,
              value: _pocketDetailItem!.value,
              total: _pocketDetailItem!.total,
              denom: _pocketDetailItem!.denom,
            );
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seal berhasil divalidasi'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Konversi detail catridge items ke CatridgeQRData untuk QR code
  List<CatridgeQRData> _prepareCatridgeQRData() {
    if (_detailCatridgeItems.isEmpty) {
      return [];
    }
    
    // Get current user data
    String userInput = 'UNKNOWN';
    try {
      final userData = _authService.getUserDataSync();
      if (userData != null) {
        userInput = userData['nik'] ?? userData['userID'] ?? userData['userCode'] ?? 'UNKNOWN';
      }
    } catch (e) {
      print('Error getting user data for QR code: $e');
    }
    
    // Ensure denomCode is not empty
    String finalDenomCode = _prepareData?.denomCode ?? '';
    if (finalDenomCode.isEmpty) finalDenomCode = 'A50';
    
    // Get tableCode and warehouseCode
    String tableCode = _prepareData?.tableCode ?? 'DEFAULT';
    String warehouseCode = 'Cideng'; // Default value
    
    // Get operator name
    String operatorName = '';
    try {
      final userData = _authService.getUserDataSync();
      if (userData != null) {
        operatorName = userData['userName'] ?? userData['name'] ?? '';
      }
    } catch (e) {
      print('Error getting operator name for QR code: $e');
    }
    
    // Convert each detail item to CatridgeQRData
    List<CatridgeQRData> result = [];
    for (var item in _detailCatridgeItems) {
      // Skip items with errors or incomplete data
      if (item.noCatridge.isEmpty || item.sealCatridge.isEmpty || item.value <= 0) {
        continue;
      }
      
      if (item.total.contains('Error') || item.total.contains('tidak ditemukan') ||
          item.sealCatridge.contains('Error') || item.sealCatridge.contains('tidak valid')) {
        continue;
      }
      
      // Create CatridgeQRData
      try {
        final catridgeData = CatridgeQRData(
          idTool: _prepareData?.id ?? int.parse(_idCRFController.text),
          bagCode: 'TEST', // Default value
          catridgeCode: item.noCatridge,
          sealCode: 'TEST', // Default value
          catridgeSeal: item.sealCatridge,
          denomCode: finalDenomCode,
          qty: '1', // Default value
          userInput: userInput,
          sealReturn: '', // Default value
          typeCatridgeTrx: 'C', // Default value for Catridge
          tableCode: tableCode,
          warehouseCode: warehouseCode,
          operatorId: userInput,
          operatorName: operatorName,
        );
        
        result.add(catridgeData);
      } catch (e) {
        print('Error creating CatridgeQRData: $e');
      }
    }
    
    // Add divert and pocket items if available
    if (_divertDetailItem != null) {
      try {
        final catridgeData = CatridgeQRData(
          idTool: _prepareData?.id ?? int.parse(_idCRFController.text),
          bagCode: _divertControllers[2].text.isNotEmpty ? _divertControllers[2].text : 'TEST',
          catridgeCode: _divertDetailItem!.noCatridge,
          sealCode: _divertControllers[3].text.isNotEmpty ? _divertControllers[3].text : 'TEST',
          catridgeSeal: _divertDetailItem!.sealCatridge,
          denomCode: finalDenomCode,
          qty: '1', // Default value
          userInput: userInput,
          sealReturn: _divertControllers[4].text.isNotEmpty ? _divertControllers[4].text : '',
          typeCatridgeTrx: 'D', // 'D' for Divert
          tableCode: tableCode,
          warehouseCode: warehouseCode,
          operatorId: userInput,
          operatorName: operatorName,
        );
        
        result.add(catridgeData);
      } catch (e) {
        print('Error creating Divert CatridgeQRData: $e');
      }
    }
    
    if (_pocketDetailItem != null) {
      try {
        final catridgeData = CatridgeQRData(
          idTool: _prepareData?.id ?? int.parse(_idCRFController.text),
          bagCode: _pocketControllers[2].text.isNotEmpty ? _pocketControllers[2].text : 'TEST',
          catridgeCode: _pocketDetailItem!.noCatridge,
          sealCode: _pocketControllers[3].text.isNotEmpty ? _pocketControllers[3].text : 'TEST',
          catridgeSeal: _pocketDetailItem!.sealCatridge,
          denomCode: finalDenomCode,
          qty: '1', // Default value
          userInput: userInput,
          sealReturn: _pocketControllers[4].text.isNotEmpty ? _pocketControllers[4].text : '',
          typeCatridgeTrx: 'P', // 'P' for Pocket
          tableCode: tableCode,
          warehouseCode: warehouseCode,
          operatorId: userInput,
          operatorName: operatorName,
        );
        
        result.add(catridgeData);
      } catch (e) {
        print('Error creating Pocket CatridgeQRData: $e');
      }
    }
    
    print('Prepared ${result.length} catridge items for QR code');
    return result;
  }
}






