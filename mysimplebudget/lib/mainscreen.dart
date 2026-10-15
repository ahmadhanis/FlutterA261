import 'package:flutter/material.dart';

import 'newbudget.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Simple Budget')),
      body: const SizedBox.expand(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const NewBudgetPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
