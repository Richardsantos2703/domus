
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class ConfiguracoesRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  static const String chaveTema = 'tema';

  /// Busca o tema salvo no banco de dados.
  /// Caso ainda não exista, retorna automático.
  Future<String> buscarTema() async {
    final Database db = await _databaseHelper.database;

    final resultado = await db.query(
      'configuracoes',
      columns: ['valor'],
      where: 'chave = ?',
      whereArgs: [chaveTema],
      limit: 1,
    );

    if (resultado.isEmpty) {
      return 'automatico';
    }

    return resultado.first['valor'] as String;
  }

  /// Salva ou atualiza a preferência de tema.
  Future<void> salvarTema(String tema) async {
    const temasPermitidos = ['claro', 'escuro', 'automatico'];

    if (!temasPermitidos.contains(tema)) {
      throw ArgumentError('Tema inválido: $tema');
    }

    final Database db = await _databaseHelper.database;

    await db.insert(
      'configuracoes',
      {
        'chave': chaveTema,
        'valor': tema,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}