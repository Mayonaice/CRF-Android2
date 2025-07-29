import 'package:flutter/material.dart';
import '../widgets/barcode_scanner_widget.dart';

class ScannerDemo extends StatefulWidget {
  const ScannerDemo({Key? key}) : super(key: key);

  @override
  State<ScannerDemo> createState() => _ScannerDemoState();
}

class _ScannerDemoState extends State<ScannerDemo> {
  // Controllers for text fields
  final TextEditingController _field1Controller = TextEditingController();
  final TextEditingController _field2Controller = TextEditingController();
  final TextEditingController _field3Controller = TextEditingController();
  
  // Map to track scanned fields
  Map<String, bool> scannedFields = {
    'field1': false,
    'field2': false,
    'field3': false,
  };
  
  // Method to scan a field
  Future<void> _scanField(String fieldName, TextEditingController controller, String fieldKey) async {
    try {
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
        title: const Text('Scanner Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFormField(
              'Field 1',
              _field1Controller,
              'field1',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Field 2',
              _field2Controller,
              'field2',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Field 3',
              _field3Controller,
              'field3',
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Reset all scan states
                setState(() {
                  scannedFields.forEach((key, value) {
                    scannedFields[key] = false;
                  });
                  _field1Controller.clear();
                  _field2Controller.clear();
                  _field3Controller.clear();
                });
              },
              child: const Text('Reset All'),
            ),
          ],
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
              // Add a checkmark indicator
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