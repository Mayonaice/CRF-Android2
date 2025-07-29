import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'prepare_mode_screen.dart';
import '../services/auth_service.dart';
import '../widgets/error_dialogs.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  String _userName = 'Lorenzo Putra'; // Default value
  String _branchName = 'JAKARTA - CIDENG'; // Default value
  String? _userRole; // NEW: Store user role
  List<String> _availableMenus = []; // NEW: Store available menus based on role

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Load user data from login
    _loadUserData();
  }

  // Enhanced user data loading with role information
  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      print('DEBUG HomePage _loadUserData - userData: $userData');
      
      // Print all possible role fields for debugging
      if (userData != null) {
        print('DEBUG HomePage _loadUserData - all role fields:');
        print('DEBUG: roleID: ${userData['roleID']}');
        print('DEBUG: RoleID: ${userData['RoleID']}');
        print('DEBUG: role: ${userData['role']}');
        print('DEBUG: Role: ${userData['Role']}');
      }
      
      final userRole = await _authService.getUserRole();
      final availableMenus = await _authService.getAvailableMenus();
      
      if (userData != null) {
        setState(() {
          _userName = userData['userName'] ?? userData['userID'] ?? userData['name'] ?? 'Lorenzo Putra';
          _branchName = userData['branchName'] ?? userData['branch'] ?? 'JAKARTA - CIDENG';
          _userRole = userRole;
          _availableMenus = availableMenus;
        });
        
        print('🎯 HOME: User role from getUserRole: $_userRole');
        print('🎯 HOME: Available menus: $_availableMenus');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // NEW: Check if menu is available for current user role
  bool _isMenuAvailable(String menuKey) {
    return _availableMenus.contains(menuKey);
  }

  // NEW: Get role-specific greeting
  String _getRoleGreeting() {
    if (_userRole == null) return 'Dashboard CRF';
    
    switch (_userRole!.toLowerCase()) {
      case 'crf_konsol':
        return 'Dashboard Konsol CRF';
      case 'crf_tl':
        return 'Dashboard Team Leader';
      case 'crf_opr':
      default:
        return 'Dashboard Operator CRF';
    }
  }

  // NEW: Get role-specific color theme
  Color _getRoleColor() {
    if (_userRole == null) return Colors.green;
    
    switch (_userRole!.toLowerCase()) {
      case 'crf_konsol':
        return Colors.blue;
      case 'crf_tl':
        return Colors.orange;
      case 'crf_opr':
      default:
        return Colors.green;
    }
  }

  // Build function card for the bottom menu row
  Widget _buildFunctionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSmallScreen,
    bool isPrepare = false,
    bool isReturn = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isPrepare 
            ? Colors.blueAccent[200] // Prepare color
            : isReturn 
                ? Colors.red[400] // Return color
                : Colors.white, // Default color
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: isPrepare || isReturn ? Colors.transparent : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : 18,
            vertical: isSmallScreen ? 12 : 18,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isSmallScreen ? 28 : 36,
                color: isPrepare || isReturn ? Colors.white : Colors.blue[700],
              ),
              SizedBox(height: isSmallScreen ? 8 : 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 14,
                  fontWeight: FontWeight.bold,
                  color: isPrepare || isReturn ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigate to Return Validation Screen
  void _navigateToReturnValidation() {
    Navigator.pushNamed(context, '/return_validation');
  }

  // NEW: Get role-specific menu label
  String _getRoleSpecificMenuLabel() {
    if (_userRole == null) return 'Menu Lain :';
    
    switch (_userRole!.toLowerCase()) {
      case 'crf_konsol':
        return 'Menu Konsol :';
      case 'crf_tl':
        return 'Menu TL :';
      case 'crf_opr':
      default:
        return 'Menu Lain :';
    }
  }

  // NEW: Build role-specific menu items
  List<Widget> _buildRoleSpecificMenus(bool isSmallScreen) {
    List<Widget> roleSpecificMenus = [];

    if (_userRole == null) return roleSpecificMenus;

    switch (_userRole!.toLowerCase()) {
      case 'crf_konsol':
        // For CRF_KONSOL, add the device_info and settings_opr buttons
        if (_isMenuAvailable('device_info'))
          roleSpecificMenus.add(_buildSmallMenuButton(
            iconAsset: 'assets/images/PhoneIcon.png',
            onTap: () => Navigator.of(context).pushNamed('/device_info'),
            isSmallScreen: isSmallScreen,
          ));
        if (_isMenuAvailable('device_info') && _isMenuAvailable('settings_opr'))
          roleSpecificMenus.add(SizedBox(width: isSmallScreen ? 15 : 20));
        if (_isMenuAvailable('settings_opr'))
          roleSpecificMenus.add(_buildSmallMenuButton(
            iconAsset: 'assets/images/PersonIcon.png',
            onTap: () => Navigator.of(context).pushNamed('/profile'),
            isSmallScreen: isSmallScreen,
          ));
        break;
      case 'crf_tl':
        if (_isMenuAvailable('dashboard_tl'))
          roleSpecificMenus.add(_buildMainMenuButton(
            context: context,
            title: 'Dashboard\nTL',
            iconAsset: 'assets/images/PrepareModeIcon.png', // Temporary icon
            route: '/dashboard_tl',
            isSmallScreen: isSmallScreen,
          ));
        if (_isMenuAvailable('team_management')) {
          roleSpecificMenus.add(SizedBox(width: isSmallScreen ? 30 : 50));
          roleSpecificMenus.add(_buildMainMenuButton(
            context: context,
            title: 'Team\nManagement',
            iconAsset: 'assets/images/ReturnModeIcon.png', // Temporary icon
            route: '/team_management',
            isSmallScreen: isSmallScreen,
          ));
        }
        break;
      case 'crf_opr':
      default:
        // For CRF_OPR, add the device_info and settings_opr buttons
        if (_isMenuAvailable('device_info'))
          roleSpecificMenus.add(_buildSmallMenuButton(
            iconAsset: 'assets/images/PhoneIcon.png',
            onTap: () => Navigator.of(context).pushNamed('/device_info'),
            isSmallScreen: isSmallScreen,
          ));
        if (_isMenuAvailable('device_info') && _isMenuAvailable('settings_opr'))
          roleSpecificMenus.add(SizedBox(width: isSmallScreen ? 15 : 20));
        if (_isMenuAvailable('settings_opr'))
          roleSpecificMenus.add(_buildSmallMenuButton(
            iconAsset: 'assets/images/PersonIcon.png',
            onTap: () => Navigator.of(context).pushNamed('/profile'),
            isSmallScreen: isSmallScreen,
          ));
        break;
    }
    return roleSpecificMenus;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        // Use new background image with responsive fit - anchor to bottom
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/bg-choosemenu.png'),
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter, // Changed to bottom center so it scales from top
          ),
        ),
        child: Column(
          children: [
            // Top section with user info and dashboard - Split into two sections with gap
            Row(
              children: [
                // Left header section - User info (2:5 ratio)
                Expanded(
                  flex: 2, // Changed to 2 for 2:5 ratio
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 15 : 25,
                      vertical: isSmallScreen ? 12 : 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7), // Much whiter with same opacity
                      borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(20),
                        // Removed topLeft and topRight to eliminate top gap
                ),
              ),
              child: Row(
                children: [
                        // User photo - using PersonIcon.png
                      CircleAvatar(
                          radius: isSmallScreen ? 25 : 35,
                          backgroundColor: Colors.blue[100],
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/PersonIcon.png',
                              width: isSmallScreen ? 45 : 60,
                              height: isSmallScreen ? 45 : 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: isSmallScreen ? 30 : 42,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 12 : 20),
                        // User name and location - Flexible to prevent overflow
                        Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                        children: [
                              Text(
                            'Selamat Datang !',
                            style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                              SizedBox(height: 4),
                          Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 10 : 15,
                                  vertical: isSmallScreen ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                                child: Text(
                                  _userName,
                              style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 16,
                                color: Colors.black,
                              ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 4 : 6),
                              Text(
                                _branchName,
                            style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 16,
                              fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            ),
                          ),
                        ],
                      ),
                  ),
                ),
                
                // Gap between headers
                SizedBox(width: isSmallScreen ? 8 : 12),
                
                // Right header section - Dashboard Trip (2:5 ratio)
                Expanded(
                  flex: 5, // Changed to 5 for 2:5 ratio
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 15 : 25,
                      vertical: isSmallScreen ? 12 : 15, // Same padding as left header
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA9D0D7), // Same color as choose menu box
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        // Removed topLeft and topRight to eliminate top gap
                      ),
                    ),
                    child: Row(
                      children: [
                        // Dashboard content
                        Expanded(
                          child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                    children: [
                              // Dashboard Trip button - FULL WIDTH
                      Container(
                                width: double.infinity, // Full width
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 20 : 30,
                                  vertical: isSmallScreen ? 8 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(30),
                        ),
                                child: Center(
                                  child: Text(
                          'Dashboard Trip',
                          style: TextStyle(
                            color: Colors.white,
                                      fontSize: isSmallScreen ? 14 : 18,
                            fontWeight: FontWeight.bold,
                                    ),
                          ),
                        ),
                      ),
                      
                              SizedBox(height: isSmallScreen ? 8 : 12),
                      
                      // Trip stats
                      Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Belum Prepare
                                  Expanded(
                                    child: _buildStatusBox(
                                      title: 'Belum Prepare',
                                      count: '1.000',
                                      isSmallScreen: isSmallScreen,
                                    ),
                                  ),
                                  
                                  SizedBox(width: isSmallScreen ? 10 : 15),
                                  
                                  // Belum Return
                                  Expanded(
                                    child: _buildStatusBox(
                                      title: 'Belum Return',
                                      count: '1.000',
                                      isSmallScreen: isSmallScreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                        SizedBox(width: isSmallScreen ? 10 : 15),
                  
                  // Clock icon
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: isSmallScreen ? 1 : 2),
                    ),
                          child: CircleAvatar(
                            radius: isSmallScreen ? 16 : 22,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.access_time,
                        color: Colors.black,
                              size: isSmallScreen ? 20 : 30,
                      ),
                    ),
                  ),
                ],
              ),
                  ),
                ),
              ],
            ),
            
            // Main content - Expanded to fill remaining space (no footer)
            Expanded(
              child: SingleChildScrollView(
              child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 15, // Reduced horizontal padding
                    vertical: isSmallScreen ? 15 : 25,
                  ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // Main menu section with background box (reduced height even more)
                      Container(
                        width: screenSize.width, // Full screen width to extend beyond margins
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 20 : 30,
                          vertical: isSmallScreen ? 6 : 10, // Reduced height even more
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA9D0D7), // Requested hex color
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Menu title with Konsol Mode button for CRF_KONSOL role
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 10), // Reduced even more
                                  child: Text(
                                    'Menu Utama :',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 20 : 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black, // Changed to black for better contrast on light blue background
                                    ),
                                  ),
                                ),
                                
                                // Konsol Mode button for CRF_KONSOL role
                                if (_userRole?.toUpperCase() == 'CRF_KONSOL' && _isMenuAvailable('konsol_mode'))
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).pushNamed('/konsol_mode'),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 12 : 16,
                                        vertical: isSmallScreen ? 8 : 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/images/KonsolModeIcon.png',
                                            width: isSmallScreen ? 24 : 28,
                                            height: isSmallScreen ? 24 : 28,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                Icons.dashboard,
                                                size: isSmallScreen ? 20 : 24,
                                                color: Colors.white,
                                              );
                                            },
                                          ),
                                          SizedBox(width: isSmallScreen ? 6 : 8),
                                          Text(
                                            'Konsol Mode',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 14 : 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            // Menu items aligned to LEFT (as requested) - NOW ROLE-BASED
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // Add some left padding to match design
                                SizedBox(width: isSmallScreen ? 20 : 40),
                                
                                // Prepare Mode button - only for CRF_OPR
                                if (_isMenuAvailable('prepare_mode'))
                                  _buildMainMenuButton(
                                    context: context,
                                    title: 'Prepare\nMode',
                                    iconAsset: 'assets/images/PrepareModeIcon.png',
                                    route: '/prepare_mode',
                                    isSmallScreen: isSmallScreen,
                                  ),
                                
                                // Add spacing only if prepare mode is shown and return mode will be shown
                                if (_isMenuAvailable('prepare_mode') && _isMenuAvailable('return_mode'))
                                  SizedBox(width: isSmallScreen ? 30 : 50),
                                
                                // Return Mode button - only for CRF_OPR
                                if (_isMenuAvailable('return_mode'))
                                  _buildMainMenuButton(
                                    context: context,
                                    title: 'Return\nMode',
                                    iconAsset: 'assets/images/ReturnModeIcon.png',
                                    route: '/return_page',
                                    isSmallScreen: isSmallScreen,
                                  ),

                                // KONSOL-specific menus
                                if (_isMenuAvailable('dashboard_konsol'))
                                  _buildMainMenuButton(
                                    context: context,
                                    title: 'Dashboard\nKonsol',
                                    iconAsset: 'assets/images/PrepareModeIcon.png', // Temporary icon
                                    route: '/dashboard_konsol',
                                    isSmallScreen: isSmallScreen,
                                  ),

                                if (_isMenuAvailable('monitoring'))
                                  SizedBox(width: isSmallScreen ? 30 : 50),

                                if (_isMenuAvailable('monitoring'))
                                  _buildMainMenuButton(
                                    context: context,
                                    title: 'Monitoring\nATM',
                                    iconAsset: 'assets/images/ReturnModeIcon.png', // Temporary icon
                                    route: '/monitoring',
                                    isSmallScreen: isSmallScreen,
                                  ),

                                // TL-specific menus
                                if (_isMenuAvailable('dashboard_tl'))
                                  _buildMainMenuButton(
                                    context: context,
                                    title: 'Dashboard\nTL',
                                    iconAsset: 'assets/images/PrepareModeIcon.png', // Temporary icon
                                    route: '/dashboard_tl',
                                    isSmallScreen: isSmallScreen,
                                  ),

                                if (_isMenuAvailable('team_management'))
                                  SizedBox(width: isSmallScreen ? 30 : 50),

                                if (_isMenuAvailable('team_management'))
                                  _buildMainMenuButton(
                                    context: context,
                                    title: 'Team\nManagement',
                                    iconAsset: 'assets/images/ReturnModeIcon.png', // Temporary icon
                                    route: '/team_management',
                                    isSmallScreen: isSmallScreen,
                                  ),
                              ],
                            ),
                            
                            SizedBox(height: isSmallScreen ? 6 : 10), // Reduced even more
                            
                            // Role-based additional menu section
                            if (_userRole != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    _getRoleSpecificMenuLabel(),
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: isSmallScreen ? 4 : 8),
                              
                              // Role-specific additional menu items
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: _buildRoleSpecificMenus(isSmallScreen),
                              ),
                            ],

                            // Original Menu Lain section - only if no role is set
                            if (_userRole == null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Menu Lain :',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: isSmallScreen ? 4 : 8),
                              
                              // Default menu items if no role is set
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildSmallMenuButton(
                                    iconAsset: 'assets/images/PhoneIcon.png',
                                    onTap: () => Navigator.of(context).pushNamed('/device_info'),
                                    isSmallScreen: isSmallScreen,
                                  ),
                                  SizedBox(width: isSmallScreen ? 15 : 20),
                                  _buildSmallMenuButton(
                                    iconAsset: 'assets/images/PersonIcon.png',
                                    onTap: () => Navigator.of(context).pushNamed('/profile'),
                                    isSmallScreen: isSmallScreen,
                                  ),
                                ],
                              ),
                            ],
                            
                            // Remove Return Validation button
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build status boxes
  Widget _buildStatusBox({
    required String title,
    required String count,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: isSmallScreen ? 12 : 18),
              SizedBox(width: isSmallScreen ? 3 : 6),
              Text(
                count,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(width: isSmallScreen ? 2 : 4),
              Text(
                'Trip',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Helper method to build main menu buttons with custom icons (enlarged with more border radius)
  Widget _buildMainMenuButton({
    required BuildContext context,
    required String title,
    required String iconAsset,
    required String route,
    required bool isSmallScreen,
  }) {
    // Increased size for bigger boxes
    final size = isSmallScreen ? 140.0 : 200.0; // Increased from 120/180
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(route);
      },
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFEBEBEB), // Changed to requested hex color
              borderRadius: BorderRadius.circular(30), // Increased border radius from 20 to 30
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                iconAsset,
                width: size * 0.6,
                height: size * 0.6,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.error,
                    size: size * 0.4,
                    color: Colors.grey,
                  );
                },
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black, // Changed to black for better contrast
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // Helper method to build small menu buttons with custom icons (enlarged even more with more border radius)
  Widget _buildSmallMenuButton({
    required String iconAsset,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isSmallScreen ? 70 : 90, // Increased even more from 60/80
        height: isSmallScreen ? 70 : 90, // Increased even more from 60/80
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15), // Increased border radius from 10 to 15
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            iconAsset,
            width: isSmallScreen ? 40 : 55, // Increased even more from 35/50
            height: isSmallScreen ? 40 : 55, // Increased even more from 35/50
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.error,
                size: isSmallScreen ? 35 : 50, // Increased even more from 30/45
                color: Colors.grey,
              );
            },
          ),
        ),
      ),
    );
  }
}