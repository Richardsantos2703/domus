
import 'package:flutter/material.dart';

import 'database/configuracoes_repository.dart';

class TemaController extends ChangeNotifier {
  final ConfiguracoesRepository _repository = ConfiguracoesRepository();

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  String get temaAtual {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'claro';
      case ThemeMode.dark:
        return 'escuro';
      case ThemeMode.system:
        return 'automatico';
    }
  }

  Future<void> carregar() async {
    final temaSalvo = await _repository.buscarTema();

    _themeMode = _converterTema(temaSalvo);

    notifyListeners();
  }

  Future<void> alterarTema(String tema) async {
    final novoTema = _converterTema(tema);

    await _repository.salvarTema(tema);

    _themeMode = novoTema;

    notifyListeners();
  }

  ThemeMode _converterTema(String tema) {
    switch (tema) {
      case 'claro':
        return ThemeMode.light;
      case 'escuro':
        return ThemeMode.dark;
      case 'automatico':
      default:
        return ThemeMode.system;
    }
  }
}

final temaController = TemaController();