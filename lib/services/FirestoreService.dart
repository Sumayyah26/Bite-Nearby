import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  // Fetch unique ingredients and allergens
  Future<Map<String, List<String>>> fetchUniqueIngredientsAndAllergens() async {
    final menuSnapshot = await FirebaseFirestore.instance
        .collection('Restaurants')
        .doc('restaurant2')
        .collection('menu')
        .get();

    final uniqueIngredients = <String>{};
    final uniqueAllergens = <String>{};

    for (var doc in menuSnapshot.docs) {
      final data = doc.data();
      uniqueIngredients.addAll(List<String>.from(data['Ingredients'] ?? []));
      uniqueAllergens.addAll(List<String>.from(data['Allergens'] ?? []));
    }

    return {
      'ingredients': uniqueIngredients.toList(),
      'allergens': uniqueAllergens.toList(),
    };
  }

  // Fetch user data
  Future<Map<String, dynamic>?> fetchUserData(String userId,
      List<String> ingredientList, List<String> allergenList) async {
    final userSnapshot = await FirebaseFirestore.instance
        .collection('Taste')
        .where('id', isEqualTo: userId)
        .get();

    if (userSnapshot.docs.isEmpty) {
      print("No data found for user $userId");
      return null;
    }

    final userData = userSnapshot.docs.first.data();
    final preferences =
        List<String>.from(userData['preferredIngredients'] ?? []);
    final allergies = List<String>.from(userData['allergens'] ?? []);

    final encodedPreferences = preferences
        .map((pref) => ingredientList.contains(pref) ? 1 : 0)
        .reduce((a, b) => a + b);
    final encodedAllergies = allergies
        .map((allergy) => allergenList.contains(allergy) ? 1 : 0)
        .reduce((a, b) => a + b);

    return {
      'userFeatures': [
        encodedPreferences.toDouble(),
        encodedAllergies.toDouble()
      ],
      'userAllergens': allergies,
    };
  }

  // Fetch item data with allergen filtering
  Future<List<Map<String, dynamic>>> fetchItemData(
      List<String> ingredientList, List<String> userAllergens) async {
    final menuSnapshot = await FirebaseFirestore.instance
        .collection('Restaurants')
        .doc('restaurant2')
        .collection('menu')
        .get();

    final items = <Map<String, dynamic>>[];

    for (var doc in menuSnapshot.docs) {
      final data = doc.data();
      final name = data['Name'] ?? 'Unknown';
      final ingredients = List<String>.from(data['Ingredients'] ?? []);
      final allergens = List<String>.from(data['Allergens'] ?? []);

      if (userAllergens.any((allergen) => allergens.contains(allergen))) {
        print("Skipping item due to allergens: $name");
        continue;
      }

      final encodedFeatures = ingredients
          .map((ing) => ingredientList.contains(ing) ? 1 : 0)
          .reduce((a, b) => a + b);

      items.add({
        'name': name,
        'features': [encodedFeatures.toDouble()]
      });
    }

    return items;
  }
}
