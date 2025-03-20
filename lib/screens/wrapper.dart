import 'package:bite_nearby/screens/authenticate/authenticate.dart';
import 'package:bite_nearby/screens/home/home.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bite_nearby/screens/models/user.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserObj?>(context);

    // home ot auth
    if (user == null) {
      return const Authenticate();
    } else {
      return const Home();
    }
  }
}
