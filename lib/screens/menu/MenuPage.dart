import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bite_nearby/services/tflite_service.dart';

class MenuPage extends StatefulWidget {
  final String restaurantId;

  MenuPage({required this.restaurantId});

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final List<String> allCategories = [
    'Your Menu',
    'Appetizers',
    'Main Course',
    'Side Dish',
    'Drinks',
    'Dessert'
  ];
  List<String> availableCategories = [];
  Map<String, GlobalKey> _categoryKeys = {};
  List<Map<String, dynamic>> personalizedMenu = [];
  String? userId;

  @override
  void initState() {
    super.initState();
    _runRecommendation(); // Call recommendation when menu opens
    _fetchAvailableCategories();
  }

  void _runRecommendation() async {
    print("🟢 Checking Firebase Auth user...");

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("⚠️ User not logged in");
      return;
    }

    print("✅ Logged-in User: ${user.uid}");
    print("🔄 Running recommendation for ${user.uid}");

    await TFLiteService().recommendDishes(user.uid, widget.restaurantId);
    _fetchPersonalizedMenu();
  }

  Future<void> _fetchPersonalizedMenu() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    userId = user.uid;

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("Users")
        .doc(userId)
        .collection("Recommendations")
        .orderBy("timestamp", descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      var data = snapshot.docs.first.data() as Map<String, dynamic>;
      List<dynamic> fetchedRecommendations = data["recommendations"] ?? [];

      setState(() {
        personalizedMenu =
            List<Map<String, dynamic>>.from(fetchedRecommendations);
      });
    }
  }

  Future<void> _fetchAvailableCategories() async {
    final menuItems = await FirebaseFirestore.instance
        .collection('Restaurants')
        .doc(widget.restaurantId)
        .collection('menu')
        .get();

    final groupedItems = _groupByCategory(menuItems.docs);

    setState(() {
      availableCategories = allCategories
          .where((category) =>
              category == 'Your Menu' || groupedItems.containsKey(category))
          .toList();

      for (String category in availableCategories) {
        _categoryKeys[category] = GlobalKey();
      }

      _tabController =
          TabController(length: availableCategories.length, vsync: this);

      _scrollController.addListener(() {
        for (int i = 0; i < availableCategories.length; i++) {
          final category = availableCategories[i];
          final context = _categoryKeys[category]?.currentContext;
          if (context != null) {
            final box = context.findRenderObject() as RenderBox;
            final position = box.localToGlobal(Offset.zero);
            if (position.dy >= 0 && position.dy < 200) {
              _tabController.animateTo(i);
              break;
            }
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        backgroundColor: Colors.green[100],
        bottom: availableCategories.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: availableCategories
                    .map((category) => Tab(text: category))
                    .toList(),
                indicatorColor: const Color.fromARGB(255, 5, 71, 37),
                labelColor: const Color.fromARGB(255, 5, 71, 37),
                unselectedLabelColor: const Color.fromARGB(179, 95, 64, 32),
                onTap: (index) {
                  final category = availableCategories[index];
                  final context = _categoryKeys[category]?.currentContext;
                  if (context != null) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              )
            : null,
      ),
      backgroundColor: Colors.white,
      body: availableCategories.isNotEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Restaurants')
                  .doc(widget.restaurantId)
                  .collection('menu')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No menu items found.'));
                }

                final menuItems = snapshot.data!.docs;
                final categoriesMap = _groupByCategory(menuItems);

                return ListView(
                  controller: _scrollController,
                  children: availableCategories.map((category) {
                    return _buildCategorySection(
                      category,
                      category == 'Your Menu'
                          ? personalizedMenu
                          : categoriesMap[category] ?? [],
                    );
                  }).toList(),
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildCategorySection(String category, List<dynamic> items) {
    return Column(
      key: _categoryKeys[category],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            category,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        ...items.map((item) {
          final data = item is DocumentSnapshot
              ? item.data() as Map<String, dynamic>
              : item;
          return _buildMenuItemCard(data);
        }).toList(),
      ],
    );
  }

  Map<String, IconData> allergenIcons = {
    'Peanuts': Icons.ac_unit,
    'Tree nuts': Icons.nature,
    'Dairy': Icons.local_drink_outlined,
    'Eggs': Icons.egg_alt,
    'Shellfish': Icons.set_meal,
    'Wheat': Icons.spa,
    'Soy': Icons.grain,
  };

  Widget _buildMenuItemCard(Map<String, dynamic> data) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MenuItemDetailsPage(itemData: data),
          ),
        );
      },
      child: Card(
        color: const Color.fromARGB(255, 255, 255, 255),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Image Section
            if (data['image_url'] != null)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(data['image_url']),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              )
            else
              Container(
                width: 100,
                height: 100,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 40),
                ),
              ),

            // Details Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item Name
                    Text(
                      data['Name'] ?? 'Unnamed Item',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Item Score (if available)
                    if (data['score'] != null)
                      Text(
                        "Score: ${data['score'].toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    const SizedBox(height: 4),

                    // Item Price
                    if (data['Price'] != null)
                      Text(
                        '${data['Price']} SR',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    const SizedBox(height: 4),

                    // Allergens Row (conditionally show if allergens exist and are valid)
                    if (data.containsKey('Allergens') &&
                        data['Allergens'] is List &&
                        (data['Allergens'] as List).isNotEmpty)
                      Row(
                        children: (data['Allergens'] as List<dynamic>)
                            .where((allergen) =>
                                allergen != null &&
                                allergenIcons.containsKey(allergen.trim()))
                            .map((allergen) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    allergenIcons[allergen.trim()],
                                    size: 20,
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<DocumentSnapshot>> _groupByCategory(
      List<DocumentSnapshot> menuItems) {
    final Map<String, List<DocumentSnapshot>> grouped = {};
    for (var item in menuItems) {
      final data = item.data() as Map<String, dynamic>;
      final category = data['Category'] ?? 'Uncategorized';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(item);
    }
    return grouped;
  }
}

class MenuItemDetailsPage extends StatelessWidget {
  final Map<String, dynamic> itemData;

  MenuItemDetailsPage({required this.itemData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(itemData['Name'] ?? 'Menu Item'),
        backgroundColor: Colors.green[100],
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 254),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            if (itemData['image_url'] != null)
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(itemData['image_url']),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 300,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 100),
                ),
              ),

            // Item Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemData['Name'] ?? 'Unnamed Item',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (itemData['Description'] != null)
                    Text(
                      itemData['Description'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (itemData['Price'] != null)
                    Text(
                      'Price: ${itemData['Price']} SR',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  const SizedBox(height: 16),
                  if (itemData['Ingredients'] != null &&
                      itemData['Ingredients'] is List)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ingredients:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ...List<String>.from(itemData['Ingredients'])
                            .map((ingredient) => Text('- $ingredient'))
                            .toList(),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            // Add to cart functionality will be implemented later
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${itemData['Name']} added to cart!'),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 212, 236, 213),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'Add to Cart',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
