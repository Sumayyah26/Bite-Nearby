import 'package:bite_nearby/services/auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bite_nearby/screens/wrapper.dart';
import 'package:provider/provider.dart';
import 'package:bite_nearby/screens/models/user.dart';
import 'package:bite_nearby/services/tflite_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _testRecommendation(); // ✅ Run ML model after app starts
  }

  /// ✅ Run Recommendation Model on App Start
  void _testRecommendation() async {
    await TFLiteService().recommendDishes(
        "r5rBTAaVduMNTBybh1xRtWObFo02", // Replace with a real user ID
        "restaurant1" // Replace with a real restaurant ID
        );
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider<UserObj?>.value(
      value: AuthService().user,
      initialData: null,
      child: const MaterialApp(
        home: Wrapper(),
      ),
    );
  }
}
