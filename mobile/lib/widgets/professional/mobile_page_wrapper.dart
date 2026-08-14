import 'package:flutter/material.dart';

class MobilePageWrapper extends StatelessWidget {
  final Widget child;

  const MobilePageWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: child,
    );
  }
}