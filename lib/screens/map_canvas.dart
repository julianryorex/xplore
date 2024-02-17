import 'package:flutter/material.dart';
import 'package:xplore/core/navbar.dart';

class MapCanvas extends StatelessWidget {
  const MapCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      bottomNavigationBar: Navbar(),
      body: Center(
        child: Text('Hello'),
      ),
    );
  }
}
