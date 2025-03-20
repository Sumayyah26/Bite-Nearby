import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch and sort restaurants by proximity
  Future<List<Map<String, dynamic>>> getSortedRestaurants() async {
    try {
      // ✅ Get user's current location
      Position userPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      print(
          "User Location: Lat=${userPosition.latitude}, Lng=${userPosition.longitude}"); // Debugging

      // ✅ Fetch restaurant data from Firestore
      QuerySnapshot querySnapshot =
          await _firestore.collection('Restaurants').get();

      List<Map<String, dynamic>> restaurants = querySnapshot.docs
          .map((doc) {
            var data = doc.data() as Map<String, dynamic>;

            if (data['location'] is GeoPoint) {
              GeoPoint restaurantLocation = data['location'];

              // ✅ Calculate distance
              double distance = Geolocator.distanceBetween(
                userPosition.latitude,
                userPosition.longitude,
                restaurantLocation.latitude,
                restaurantLocation.longitude,
              );

              print(
                  "${data['Name']} is ${distance.toStringAsFixed(2)} meters away"); // Debugging

              return {
                'id': doc.id,
                'name': data['Name'] ?? 'Unnamed Restaurant',
                'location': restaurantLocation,
                'distance': distance,
                'rating': data['rating'] ?? 0.0,
                'image_url': data['image_url'] ?? '',
              };
            } else {
              print(
                  "Skipping ${data['Name']} - Invalid Location Format"); // Debugging
              return null;
            }
          })
          .where((restaurant) => restaurant != null)
          .cast<Map<String, dynamic>>()
          .toList();

      // ✅ Sort restaurants by distance (nearest first)
      restaurants.sort((a, b) => a['distance'].compareTo(b['distance']));
      print(
          "Sorted Restaurants: ${restaurants.map((r) => r['name']).toList()}"); // Debugging

      return restaurants;
    } catch (e) {
      print("Error fetching restaurants: $e");
      return [];
    }
  }
}
