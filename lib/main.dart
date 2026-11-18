
import 'package:flutter/material.dart';

import 'database/recorrencias_gerador.dart';
import 'tela_inicial.dart';

void main() {
  runApp(const DomusApp());
}

class DomusApp extends StatefulWidget {
  final Future<int> Function()? gerarRecorrencias;

  const DomusApp({
    super.key,
    this.gerarRecorrencias,
  });

  @override
  State<DomusApp> createState() => _DomusAppState();
}

class _DomusAppState extends State<DomusApp> {
  late Future<int> _inicializacao;

  Future<int> _gerarContas() {
    return widget.gerarRecorrencias?.call() ??
        RecorrenciasGerador().gerarContas();
  }

  @override
  void initState() {
    super.initState();
    _inicializacao = _gerarContas();
  }

  void _tentarNovamente() {
    setState(() {
      _inicializacao = _gerarContas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: FutureBuilder<int>(
        future: _inicializacao,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Preparando suas contas...'),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Não foi possível preparar suas contas.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _tentarNovamente,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return const TelaInicial();
        },
      ),
    );
  }
}