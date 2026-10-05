import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: MyCalc(),
    );
  }
}

class MyCalc extends StatefulWidget {
  const MyCalc({super.key});

  @override
  State<MyCalc> createState() => _MyCalcState();
}

class _MyCalcState extends State<MyCalc> {
  final TextEditingController _txtcontroller1 = TextEditingController();
  final TextEditingController _txtcontroller2 = TextEditingController();
  double val1 = 0.0;
  double val2 = 0.0;
  double result = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Simple Calculator'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(controller: _txtcontroller1),
              TextField(controller: _txtcontroller2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      calculateplus();
                    },
                    child: const Text('+'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      calculateminus();
                    },
                    child: const Text('-'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      calculatemultiply();
                    },
                    child: const Text('*'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      calculatedivide();
                    },
                    child: const Text('/'),
                  ),
                ],
              ),
              Text('Result: $result', style: const TextStyle(fontSize: 20.0)),
            ],
          ),
        ),
      ),
    );
  }

  void calculateplus() {
    val1 = double.tryParse(_txtcontroller1.text) ?? 0.0;
    val2 = double.tryParse(_txtcontroller2.text) ?? 0.0;
    result = val1 + val2;
    setState(() {});
  }

  void calculateminus() {
    val1 = double.tryParse(_txtcontroller1.text) ?? 0.0;
    val2 = double.tryParse(_txtcontroller2.text) ?? 0.0;
    result = val1 - val2;
    setState(() {});
  }

  void calculatemultiply() {
    val1 = double.tryParse(_txtcontroller1.text) ?? 0.0;
    val2 = double.tryParse(_txtcontroller2.text) ?? 0.0;
    result = val1 * val2;
    setState(() {});
  }

  void calculatedivide() {
    val1 = double.tryParse(_txtcontroller1.text) ?? 0.0;
    val2 = double.tryParse(_txtcontroller2.text) ?? 0.0;
    result = val1 / val2;
    setState(() {});
  }
}
