import 'package:location/location.dart' as loc;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<Map<String, dynamic>> getCurrentLocation() async {
    loc.Location location = loc.Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }
    }

    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        throw Exception("Location permission denied.");
      }
    }

    loc.LocationData locationData = await location.getLocation();

    double latitude = locationData.latitude ?? 0.0;
    double longitude = locationData.longitude ?? 0.0;

    // ✅ Get Address from Coordinates
    String address = await getAddressFromCoordinates(latitude, longitude);

    print("Fetched User Location: $address"); // Debugging

    return {
      'geoPoint': GeoPoint(latitude, longitude),
      'address': address, // ✅ Store readable address
    };
  }

  // ✅ Reverse Geocode to Get Address
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.street}, ${place.locality}, ${place.country}";
      }
      return "Unknown location";
    } catch (e) {
      print("Error fetching address: $e");
      return "Unknown location";
    }
  }
}
