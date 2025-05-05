// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:hostel_connect/screens/student/home_screen.dart';
// import 'package:hostel_connect/screens/owner/manage_hostels_screen.dart';
// import 'package:hostel_connect/screens/owner/analytics_screen.dart';
// import 'package:hostel_connect/screens/owner/owner_bookings_screen.dart';
// import 'package:hostel_connect/screens/student/hostel_list_screen.dart';
// import 'package:hostel_connect/screens/student/bookings_screen.dart';
// import 'package:hostel_connect/screens/student/profile_screen.dart';

// final supabase = Supabase.instance.client;

// class MainWrapper extends StatefulWidget {
//   const MainWrapper({Key? key}) : super(key: key);

//   @override
//   _MainWrapperState createState() => _MainWrapperState();
// }

// class _MainWrapperState extends State<MainWrapper> {
//   int _selectedIndex = 0;
//   String? _userType;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserType();
//   }

//   Future<void> _loadUserType() async {
//     final userId = supabase.auth.currentUser?.id;
//     if (userId != null) {
//       final response = await supabase
//           .from('profiles')
//           .select('user_type')
//           .eq('id', userId)
//           .single();
      
//       setState(() {
//         _userType = response['user_type'] ?? 'student';
//       });
//     }
//   }

//   List<Widget> _ownerScreens() {
//     return [
//       const HomeScreen(), // Shared home screen
//       const ManageHostelsScreen(),
//       const OwnerBookingsScreen(),
//       const AnalyticsScreen(),
//     ];
//   }

//   List<Widget> _studentScreens() {
//     return [
//       const HomeScreen(),
//       const HostelListScreen(),
//       const BookingsScreen(),
//       const ProfileScreen(),
//     ];
//   }

//   List<BottomNavigationBarItem> _ownerNavItems() {
//     return const [
//       BottomNavigationBarItem(
//         icon: Icon(Icons.home_outlined),
//         activeIcon: Icon(Icons.home),
//         label: 'Home',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.apartment_outlined),
//         activeIcon: Icon(Icons.apartment),
//         label: 'My Hostels',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.book_online_outlined),
//         activeIcon: Icon(Icons.book_online),
//         label: 'Bookings',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.analytics_outlined),
//         activeIcon: Icon(Icons.analytics),
//         label: 'Analytics',
//       ),
//     ];
//   }

//   List<BottomNavigationBarItem> _studentNavItems() {
//     return const [
//       BottomNavigationBarItem(
//         icon: Icon(Icons.home_outlined),
//         activeIcon: Icon(Icons.home),
//         label: 'Home',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.search_outlined),
//         activeIcon: Icon(Icons.search),
//         label: 'Explore',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.bookmark_border_outlined),
//         activeIcon: Icon(Icons.bookmark),
//         label: 'Bookings',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.person_outline),
//         activeIcon: Icon(Icons.person),
//         label: 'Profile',
//       ),
//     ];
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_userType == null) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     final isOwner = _userType == 'owner';
//     final screens = isOwner ? _ownerScreens() : _studentScreens();
//     final navItems = isOwner ? _ownerNavItems() : _studentNavItems();

//     return Scaffold(
//       body: screens[_selectedIndex],
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               blurRadius: 10,
//               offset: const Offset(0, -5),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//           child: BottomNavigationBar(
//             currentIndex: _selectedIndex,
//             onTap: (index) {
//               setState(() {
//                 _selectedIndex = index;
//               });
//             },
//             selectedItemColor: const Color(0xFF3498db),
//             unselectedItemColor: const Color(0xFF7f8c8d),
//             backgroundColor: Colors.white,
//             elevation: 0,
//             type: BottomNavigationBarType.fixed,
//             items: navItems,
//           ),
//         ),
//       ),
//     );
//   }
// }