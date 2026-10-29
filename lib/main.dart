import 'package:flutter/material.dart';
import 'tela_inicial.dart';

void main() {
  runApp(const DomusApp());
}

class DomusApp extends StatelessWidget {
  const DomusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const TelaInicial(),
    );
  }
}