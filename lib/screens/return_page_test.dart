import 'package:flutter/material.dart';
import '../widgets/barcode_scanner_widget.dart';

void main() {
  runApp(const ReturnPageTestApp());
}

class ReturnPageTestApp extends StatelessWidget {
  const ReturnPageTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Return Page Test',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const ReturnPageTest(),
    );
  }
}

class ReturnPageTest extends StatefulWidget {
  const ReturnPageTest({Key? key}) : super(key: key);

  @override
  State<ReturnPageTest> createState() => _ReturnPageTestState();
}

class _ReturnPageTestState extends State<ReturnPageTest> {
  // Controllers for text fields
  final TextEditingController _noCatridgeController = TextEditingController();
  final TextEditingController _noSealController = TextEditingController();
  final TextEditingController _catridgeFisikController = TextEditingController();
  
  // Map to track scanned fields
  Map<String, bool> scannedFields = {
    'noCatridge': false,
    'noSeal': false,
    'catridgeFisik': false,
  };
  
  // Method to scan a field
  Future<void> _scanField(String fieldName, TextEditingController controller, String fieldKey) async {
    try {
      print('Starting scan for $fieldName (fieldKey: $fieldKey)');
      
      // Navigate to barcode scanner
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Scan $fieldName',
            onBarcodeDetected: (String barcode) {
              // Just return the barcode to handle in parent method
              Navigator.of(context).pop(barcode);
            },
          ),
        ),
      );
      
      // If barcode was scanned
      if (result != null && result.isNotEmpty) {
        print('Scanned barcode for $fieldName: $result');
        
        // Update the controller text
        controller.text = result;
        
        // Update the scanned status
        setState(() {
          scannedFields[fieldKey] = true;
          print('Updated scan status for $fieldKey to true');
          print('Current scan status: $scannedFields');
        });
      } else {
        print('Scan cancelled or empty result for $fieldName');
      }
    } catch (e) {
      print('Error scanning $fieldName: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Page Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catridge Details',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16.0),
                _buildFormField(
                  'No. Catridge*',
                  _noCatridgeController,
                  'noCatridge',
                ),
                const SizedBox(height: 16.0),
                _buildFormField(
                  'No. Seal*',
                  _noSealController,
                  'noSeal',
                ),
                const SizedBox(height: 16.0),
                _buildFormField(
                  'Catridge Fisik*',
                  _catridgeFisikController,
                  'catridgeFisik',
                ),
                const SizedBox(height: 32.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Reset all scan states
                        setState(() {
                          scannedFields.forEach((key, value) {
                            scannedFields[key] = false;
                          });
                          _noCatridgeController.clear();
                          _noSealController.clear();
                          _catridgeFisikController.clear();
                        });
                      },
                      child: const Text('Reset All'),
                    ),
                    const SizedBox(width: 16.0),
                    ElevatedButton(
                      onPressed: () {
                        // Simulate successful scan for all fields
                        setState(() {
                          _noCatridgeController.text = 'CAT123';
                          _noSealController.text = 'SEAL456';
                          _catridgeFisikController.text = 'FISIK789';
                          
                          scannedFields['noCatridge'] = true;
                          scannedFields['noSeal'] = true;
                          scannedFields['catridgeFisik'] = true;
                          
                          print('Simulated scan for all fields');
                          print('Current scan status: $scannedFields');
                        });
                      },
                      child: const Text('Simulate Scan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper to build form fields with scan button
  Widget _buildFormField(
    String label,
    TextEditingController controller,
    String fieldKey,
  ) {
    // Check if this field has been scanned
    bool isScanned = scannedFields[fieldKey] == true;
    
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            readOnly: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              // Add a very visible checkmark indicator
              suffixIcon: isScanned 
                ? Container(
                    margin: const EdgeInsets.all(8.0),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16.0,
                    ),
                  )
                : null,
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        ElevatedButton.icon(
          onPressed: () => _scanField(label, controller, fieldKey),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan'),
        ),
      ],
    );
  }
} 