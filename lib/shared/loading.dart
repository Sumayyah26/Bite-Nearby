import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.green[100],
      child: Center(
        child: SpinKitThreeBounce(
          color: Colors.orangeAccent[400],
          size: 50.0,
        ),
      ),
    );
  }
}
