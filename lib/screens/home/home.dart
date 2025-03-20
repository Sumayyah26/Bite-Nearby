import 'package:flutter/material.dart';
import 'package:bite_nearby/services/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bite_nearby/screens/home/prefrences.dart';
import 'package:bite_nearby/screens/home/orders.dart';
import 'package:bite_nearby/screens/menu/Restaurants.dart';
import 'package:location/location.dart';
import 'package:bite_nearby/services/location.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<Home> {
  final AuthService _auth = AuthService();
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  String? _currentLocation; // To store user's current location
  bool _isFetchingLocation = false;
  @override
  void initState() {
    super.initState();
    _fetchLocation(); // Fetch the location when the widget is initialized
  }

  Future<String?> _getUsername() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot snapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();
        if (snapshot.exists && snapshot.data() != null) {
          return snapshot.get('username');
        }
      } catch (e) {
        print('Error fetching username: $e');
      }
    }
    return "Guest";
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          return;
        }
      }

      LocationData locationData = await location.getLocation();
      setState(() {
        _currentLocation =
            "Lat: ${locationData.latitude?.toStringAsFixed(2)}, Long: ${locationData.longitude?.toStringAsFixed(2)}";
        _isFetchingLocation = false;
      });
    } catch (e) {
      print('Error fetching location: $e');
      setState(() {
        _currentLocation = "Location unavailable";
        _isFetchingLocation = false;
      });
    }
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        radius: 25.0,
                      ),
                      const SizedBox(width: 8.0),
                      FutureBuilder<String?>(
                        future: _getUsername(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (snapshot.hasError) {
                            return const Text(
                              "Error",
                              style: TextStyle(color: Colors.red),
                            );
                          }
                          String username = snapshot.data ?? "Guest";
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Welcome",
                                style: TextStyle(
                                    fontSize: 16.0, color: Colors.teal[800]),
                              ),
                              Text(
                                username,
                                style: TextStyle(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[800],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_isFetchingLocation)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(),
                        )
                      else
                        Text(
                          _currentLocation ?? "Fetching location...",
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.teal[800],
                          ),
                        ),
                      const SizedBox(width: 8.0),
                      TextButton.icon(
                        onPressed: () async {
                          await _auth.signOut();
                        },
                        icon: const Icon(Icons.person, color: Colors.white),
                        label: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: onTabTapped,
                  children: [
                    Center(
                      child: Text(
                        "Home Page Content Goes Here",
                        style:
                            TextStyle(fontSize: 18.0, color: Colors.teal[800]),
                      ),
                    ),
                    PreferencesPage(),
                    const OrdersPage(),
                    RestaurantListPage(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white, // ✅ Change background to white
        selectedItemColor: Colors.black, // ✅ Selected item color
        unselectedItemColor: Colors.grey, // ✅ Unselected item color
        type: BottomNavigationBarType.fixed, // ✅ Keeps all labels visible
        onTap: onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'My Preferences',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Previous Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Restaurants',
          ),
        ],
      ),
    );
  }
}
