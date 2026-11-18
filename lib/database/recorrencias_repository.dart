import 'package:domus/database/database_helper.dart';

class RecorrenciasRepository {
  // Cadastra uma nova recorrência.
  Future<int> adicionar(Map<String, Object?> dados) async {
    final db = await DatabaseHelper.instance.database;

    return await db.insert('recorrencias', dados);
  }

  // Lista todas as recorrências.
  Future<List<Map<String, Object?>>> listar() async {
    final db = await DatabaseHelper.instance.database;

    return await db.query('recorrencias', orderBy: 'ativa DESC, nome ASC');
  }

  // Busca uma recorrência pelo ID.
  Future<Map<String, Object?>?> buscarPorId(int id) async {
    final db = await DatabaseHelper.instance.database;

    final resultado = await db.query(
      'recorrencias',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultado.isEmpty) {
      return null;
    }

    return resultado.first;
  }

  // Lista somente as recorrências ativas.
  Future<List<Map<String, Object?>>> listarAtivas() async {
    final db = await DatabaseHelper.instance.database;

    return await db.query(
      'recorrencias',
      where: 'ativa = ?',
      whereArgs: [1],
      orderBy: 'nome ASC',
    );
  }

  // Atualiza os dados de uma recorrência.
  Future<int> atualizar(int id, Map<String, Object?> dados) async {
    final db = await DatabaseHelper.instance.database;

    return await db.update(
      'recorrencias',
      dados,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Ativa uma recorrência.
  Future<int> ativar(int id) async {
    final db = await DatabaseHelper.instance.database;

    return await db.update(
      'recorrencias',
      {'ativa': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Desativa uma recorrência.
  // As contas já geradas permanecem no banco.
  Future<int> desativar(int id) async {
    final db = await DatabaseHelper.instance.database;

    return await db.update(
      'recorrencias',
      {'ativa': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Exclui uma recorrência.
  // As contas vinculadas permanecem, mas perdem o vínculo.
  Future<int> excluir(int id) async {
    final db = await DatabaseHelper.instance.database;

    return await db.delete('recorrencias', where: 'id = ?', whereArgs: [id]);
  }
}
