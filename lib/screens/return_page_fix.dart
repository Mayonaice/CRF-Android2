// Here's the missing _buildFormField method for _ReturnModePageState class

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
    height: isSmallScreen ? 40 : 50,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Label section - fixed width
        SizedBox(
          width: isSmallScreen ? 80 : 100,
          child: Padding(
            padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
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
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
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
                    onChanged: onChanged,
                  ),
                ),
                
                // Icons positioned on the underline
                if (enableScan)
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
                      onPressed: onIconPressed,
                    ),
                  ),
                
                if (hasIcon)
                  Container(
                    width: isSmallScreen ? 30 : 40,
                    height: isSmallScreen ? 30 : 40,
                    margin: EdgeInsets.only(
                      left: isSmallScreen ? 4 : 6,
                      bottom: isSmallScreen ? 3 : 4,
                    ),
                    child: Icon(
                      iconData,
                      color: Colors.grey,
                      size: isSmallScreen ? 20 : 24,
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