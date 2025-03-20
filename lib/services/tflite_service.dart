import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TFLiteService {
  late Interpreter interpreter;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool _isModelLoaded = false;

  /// ✅ Load ML Model (Ensures it's loaded only once)
  Future<void> loadModel() async {
    if (_isModelLoaded) return; // Prevent multiple loads
    try {
      interpreter =
          await Interpreter.fromAsset('assets/recommendation_model.tflite');
      _isModelLoaded = true;
      print("✅ Model Loaded Successfully");
    } catch (e) {
      print("❌ Error loading model: $e");
    }
  }

  Future<Map<String, dynamic>> getUserPreferences(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await firestore.collection("Users").doc(userId).get();
      if (userDoc.exists) {
        print("✅ User Preferences Loaded for $userId");
        return userDoc.data() as Map<String, dynamic>;
      } else {
        print("⚠️ No user preferences found for $userId");
        return {};
      }
    } catch (e) {
      print("❌ Error fetching user data: $e");
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getMenuItemsWithoutAllergens(
      String restaurantId, List<String> userAllergens) async {
    try {
      QuerySnapshot menuSnapshot = await firestore
          .collection("Restaurants")
          .doc(restaurantId)
          .collection("menu")
          .get();

      List<Map<String, dynamic>> filteredItems = [];

      for (var doc in menuSnapshot.docs) {
        Map<String, dynamic> menuItem = doc.data() as Map<String, dynamic>;
        List<dynamic> allergens = menuItem["Allergens"] ?? [];

        bool hasAllergen = allergens
            .any((allergen) => userAllergens.contains(allergen.trim()));
        if (!hasAllergen) {
          filteredItems.add(menuItem);
        }
      }
      print("✅ Found ${filteredItems.length} safe menu items for user");
      return filteredItems;
    } catch (e) {
      print("❌ Error fetching menu items: $e");
      return [];
    }
  }

  Future<void> recommendDishes(String userId, String restaurantId) async {
    print("🟢 recommendDishes() called for user: $userId");

    await loadModel(); // Ensure model is loaded before running
    print("✅ Model loaded successfully");

    Map<String, dynamic> userPreferences = await getUserPreferences(userId);
    List<String> userAllergens =
        List<String>.from(userPreferences["allergens"] ?? []);

    print("👤 User Preferences: ${userPreferences.toString()}");

    List<Map<String, dynamic>> safeMenuItems =
        await getMenuItemsWithoutAllergens(restaurantId, userAllergens);

    if (safeMenuItems.isEmpty) {
      print("⚠️ No safe menu items found for recommendation.");
      return;
    }

    List<Map<String, dynamic>> recommendations = [];

    for (var item in safeMenuItems) {
      int foodId = int.tryParse(item["id"].toString()) ?? 0;
      if (foodId == 0) continue; // Skip invalid food IDs

      for (var item in safeMenuItems) {
        int foodId = int.tryParse(item["id"].toString()) ?? 0;
        if (foodId == 0) continue; // Skip invalid food IDs

        var input = [
          [int.tryParse(userId) ?? 0], // Convert user ID
          [foodId]
        ];
        var output = List.filled(1, 0.0).reshape([1, 1]);

        print(
            "🔹 [BEFORE] Model Input: UserID: ${int.tryParse(userId)}, FoodID: $foodId");

        try {
          interpreter.run(input, output);
          double prediction = output[0][0];

          print(
              "🟢 [AFTER] Model Output for ${item["Name"]} (Food ID: $foodId): $prediction");

          if (prediction >= 0.0) {
            // Prevent negative values
            recommendations.add({
              "foodId": foodId,
              "name": item["Name"],
              "score": prediction,
            });
          } else {
            print(
                "⚠️ Skipping ${item["Name"]} (ID: $foodId) - Prediction too low!");
          }
        } catch (e) {
          print("❌ ML Model Error for ${item["Name"]}: $e");
        }
      }
    }

    print("🔍 Final Recommendations to Save:");
    for (var rec in recommendations) {
      print("➡️ ${rec["name"]} (Score: ${rec["score"]})");
    }
    if (recommendations.isEmpty) {
      print("⚠️ No recommendations generated. Check model output.");
    } else {
      print(
          "🔍 Recommendations to Save: ${recommendations.map((r) => "${r["name"]} (Score: ${r["score"]})").toList()}");
    }

    // ✅ Save Recommendations to Firestore
    try {
      await firestore
          .collection("Users")
          .doc(userId)
          .collection("Recommendations")
          .doc(restaurantId)
          .set({
        "timestamp": DateTime.now(),
        "recommendations": recommendations,
      });

      print(
          "✅ Recommendations saved for user $userId in restaurant $restaurantId");
    } catch (e) {
      print("❌ Error saving recommendations: $e");
    }
  }
}
