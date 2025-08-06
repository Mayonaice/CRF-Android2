import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/return_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/error_dialogs.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../widgets/logout_dialog.dart';
import '../widgets/custom_modals.dart';

class ReturnModeScreen extends StatefulWidget {
  const ReturnModeScreen({Key? key}) : super(key: key);

  @override
  _ReturnModeScreenState createState() => _ReturnModeScreenState();
}

class _ReturnModeScreenState extends State<ReturnModeScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _idCrfController = TextEditingController();
  final TextEditingController _jamMulaiController = TextEditingController();
  
  String _userName = '';
  String _branchCode = '';
  String _branchName = '';
  String _noMeja = '';
  
  bool _isLoading = false;
  bool _dataLoaded = false;
  String _errorMessage = '';
  
  List<ReturnCatridgeData> _returnCatridgeList = [];
  List<DetailReturnItem> _detailReturnItems = [];
  
  // WSID details
  String _wsid = '';
  String _bank = '';
  String _lokasi = '';
  String _atmType = '';
  DateTime? _tanggalReplenish;
  
  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Load user data
    _loadUserData();
    
    // Set current time in jam mulai
    _setCurrentTime();
  }
  
  void _setCurrentTime() {
    final now = DateTime.now();
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _jamMulaiController.text = formattedTime;
  }
  
  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userName = userData['userName'] ?? '';
          _branchCode = userData['branchCode'] ?? userData['BranchCode'] ?? '';
          _branchName = userData['branchName'] ?? userData['BranchName'] ?? '';
          _noMeja = userData['idMeja'] ?? userData['IDMeja'] ?? '';
        });
        debugPrint('UserData loaded: ' + userData.toString());
        debugPrint('BranchCode loaded: $_branchCode');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }
  
  Future<void> _loadReturnCatridgeData() async {
    if (_idCrfController.text.isEmpty) {
      showErrorDialog(context, 'Error', 'ID CRF tidak boleh kosong');
      return;
    }
    if (_branchCode.isEmpty) {
      showErrorDialog(context, 'Error', 'BranchCode belum terisi. Silakan login ulang atau cek data user.');
      return;
    }
    debugPrint('BranchCode yang dikirim: $_branchCode');

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _dataLoaded = false;
    });

    try {
      final response = await _apiService.getReturnHeaderAndCatridge(
        _idCrfController.text,
        branchCode: _branchCode,
      );
      if (response.success) {
        setState(() {
          _returnCatridgeList = response.data;
          _dataLoaded = true;
          _errorMessage = '';
          if (response.header != null) {
            _wsid = response.header!.atmCode;
            _bank = response.header!.namaBank;
            _lokasi = response.header!.lokasi;
            _atmType = response.header!.typeATM;
          }
          // Create detail return items
          _detailReturnItems = [];
          for (int i = 0; i < _returnCatridgeList.length; i++) {
            final catridge = _returnCatridgeList[i];
            _detailReturnItems.add(
              DetailReturnItem(
                index: i + 1,
                noCatridge: catridge.catridgeCode,
                sealCatridge: catridge.catridgeSeal,
                value: 0,
                total: '',
                denom: catridge.denomCode,
              ),
            );
          }
        });
      } else {
        setState(() {
          _errorMessage = response.message;
          _dataLoaded = false;
        });
        showErrorDialog(context, 'Error', response.message);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _dataLoaded = false;
      });
      showErrorDialog(context, 'Error', 'Gagal memuat data:  e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _submitReturnData() async {
    // Implementation for submitting return data
    // This would call the insertReturnAtmCatridge method from the API service
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin mengirim data return?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement the actual submission here
              showErrorDialog(context, 'Sukses', 'Data return berhasil dikirim');
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _scanBarcode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerWidget(
          title: 'Scan Barcode',
          onBarcodeDetected: (String code) {
            setState(() {
              _idCrfController.text = code;
            });
            _loadReturnCatridgeData();
          },
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _idCrfController.dispose();
    _jamMulaiController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg-app.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              height: isSmallScreen ? 70 : 80,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 24.0 : 32.0,
                vertical: isSmallScreen ? 12.0 : 16.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Menu button - Green hamburger icon
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: isSmallScreen ? 40 : 48,
                      height: isSmallScreen ? 40 : 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 16 : 20),
                  
                  // Title
                  Text(
                    'Return Mode',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Location info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _branchName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Meja : $_noMeja',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(width: isSmallScreen ? 20 : 24),
                  
                  // CRF_OPR button
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: isSmallScreen ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      'CRF_OPR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  
                  // Menu button (3 horizontal lines)
                  Container(
                    width: isSmallScreen ? 40 : 44,
                    height: isSmallScreen ? 40 : 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  
                  SizedBox(width: isSmallScreen ? 20 : 24),
                  
                  // User info
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            constraints: BoxConstraints(maxWidth: isSmallScreen ? 120 : 150),
                            child: Text(
                              _userName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _authService.getUserData(),
                            builder: (context, snapshot) {
                              String nik = '';
                              if (snapshot.hasData && snapshot.data != null) {
                                nik = snapshot.data!['userId'] ?? 
                                      snapshot.data!['userID'] ?? 
                                      '';
                              } else {
                                nik = '';
                              }
                              return Text(
                                nik,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B7280),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(width: isSmallScreen ? 10 : 12),
                      Container(
                        width: isSmallScreen ? 44 : 48,
                        height: isSmallScreen ? 44 : 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            color: const Color(0xFF10B981),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Main content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left panel - Input form
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ID CRF and Jam Mulai inputs
                          Row(
                            children: [
                              // ID CRF
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ID CRF :',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _idCrfController,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        IconButton(
                                          icon: const Icon(Icons.qr_code_scanner),
                                          onPressed: _scanBarcode,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              // Jam Mulai
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Jam Mulai :',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _jamMulaiController,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                            ),
                                            readOnly: true,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        IconButton(
                                          icon: const Icon(Icons.access_time),
                                          onPressed: _setCurrentTime,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 15),
                          
                          // Load button
                          Center(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _loadReturnCatridgeData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Load Data',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 15),
                          
                          // Error message
                          if (_errorMessage.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          
                          const SizedBox(height: 15),
                          
                          // WSID details
                          if (_dataLoaded)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Detail WSID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('WSID :'),
                                            Text(
                                              _wsid,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Bank :'),
                                            Text(
                                              _bank,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Lokasi :'),
                                            Text(
                                              _lokasi,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('ATM Type :'),
                                            Text(
                                              _atmType,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Tanggal Replenish :'),
                                            Text(
                                              _tanggalReplenish != null
                                                  ? '${_tanggalReplenish!.day}/${_tanggalReplenish!.month}/${_tanggalReplenish!.year}'
                                                  : '-',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 15),
                          
                          // Catridge section
                          if (_dataLoaded)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Catridge Return',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _returnCatridgeList.length,
                                      itemBuilder: (context, index) {
                                        final catridge = _returnCatridgeList[index];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          child: ListTile(
                                            title: Text('Catridge: ${catridge.catridgeCode}'),
                                            subtitle: Text(
                                              'Seal: ${catridge.catridgeSeal} | Denom: ${catridge.denomCode}',
                                            ),
                                            trailing: Text(
                                              'Total: -',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Submit button
                          if (_dataLoaded)
                            Center(
                              child: ElevatedButton(
                                onPressed: _submitReturnData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Submit Data',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Right panel - Detail Return
                  if (_dataLoaded)
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detail Return',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _detailReturnItems.length,
                                itemBuilder: (context, index) {
                                  final item = _detailReturnItems[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Catridge ${item.index}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('No Catridge:'),
                                                    Text(
                                                      item.noCatridge,
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Seal:'),
                                                    Text(
                                                      item.sealCatridge,
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Denom:'),
                                                    Text(
                                                      item.denom,
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Value:'),
                                                    Text(
                                                      item.value.toString(),
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Total:'),
                                                    Text(
                                                      item.total,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            // Grand total
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Grand Total: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Rp 0',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 

// Use CustomModals for error dialogs
void showErrorDialog(BuildContext context, String title, String message) {
  if (title.toLowerCase() == 'sukses' || title.toLowerCase() == 'success') {
    CustomModals.showSuccessModal(
      context: context,
      message: message,
    );
  } else {
    CustomModals.showFailedModal(
      context: context,
      message: message,
    );
  }
}

// Use CustomModals for logout confirmation
void showLogoutDialog(BuildContext context) {
  CustomModals.showConfirmationModal(
    context: context,
    message: 'Apakah Anda yakin ingin logout?',
    confirmText: 'Logout',
    cancelText: 'Batal',
  ).then((confirmed) {
    if (confirmed) {
      // Add logout logic if needed
    }
  });
} 