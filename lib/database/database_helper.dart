import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  static const int _databaseVersion = 1;
  static const String _databaseName = 'domus.db';

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Categorias
    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        cor TEXT NOT NULL,
        padrao INTEGER NOT NULL DEFAULT 0
          CHECK (padrao IN (0, 1))
      )
    ''');

    // Impede a exclusão das categorias padrão.
    await db.execute('''
      CREATE TRIGGER impedir_exclusao_categoria_padrao
      BEFORE DELETE ON categorias
      WHEN OLD.padrao = 1
      BEGIN
        SELECT RAISE(
          ABORT,
          'Categorias padrao nao podem ser excluidas'
        );
      END;
    ''');

    // 2. Recorrências
    await db.execute('''
      CREATE TABLE recorrencias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        valor_previsto_centavos INTEGER NOT NULL
          CHECK (valor_previsto_centavos > 0),
        categoria_id INTEGER NOT NULL,
        frequencia TEXT NOT NULL
          CHECK (frequencia IN ('mensal', 'anual')),
        dia_vencimento INTEGER NOT NULL
          CHECK (dia_vencimento BETWEEN 1 AND 31),
        mes_vencimento INTEGER,
        descricao TEXT,
        ativa INTEGER NOT NULL DEFAULT 1
          CHECK (ativa IN (0, 1)),
        criada_em TEXT NOT NULL,

        FOREIGN KEY (categoria_id)
          REFERENCES categorias(id)
          ON DELETE RESTRICT,

        CHECK (
          (
            frequencia = 'mensal'
            AND mes_vencimento IS NULL
          )
          OR
          (
            frequencia = 'anual'
            AND mes_vencimento IS NOT NULL
            AND mes_vencimento BETWEEN 1 AND 12
          )
        )
      )
    ''');

    // 3. Contas
    await db.execute('''
      CREATE TABLE contas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        valor_total_centavos INTEGER NOT NULL
          CHECK (valor_total_centavos > 0),
        categoria_id INTEGER NOT NULL,
        recorrencia_id INTEGER,
        data_vencimento TEXT NOT NULL,
        descricao TEXT,
        criada_em TEXT NOT NULL,

        FOREIGN KEY (categoria_id)
          REFERENCES categorias(id)
          ON DELETE RESTRICT,

        FOREIGN KEY (recorrencia_id)
          REFERENCES recorrencias(id)
          ON DELETE SET NULL
      )
    ''');

    // Impede contas duplicadas da mesma recorrência.
    await db.execute('''
      CREATE UNIQUE INDEX idx_contas_recorrencia_vencimento
      ON contas (recorrencia_id, data_vencimento)
      WHERE recorrencia_id IS NOT NULL
    ''');

    // Índices para agilizar consultas.
    await db.execute('''
      CREATE INDEX idx_contas_vencimento
      ON contas (data_vencimento)
    ''');

    await db.execute('''
      CREATE INDEX idx_contas_categoria
      ON contas (categoria_id)
    ''');

    // 4. Pagamentos
    await db.execute('''
      CREATE TABLE pagamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conta_id INTEGER NOT NULL,
        valor_pago_centavos INTEGER NOT NULL
          CHECK (valor_pago_centavos > 0),
        data_pagamento TEXT NOT NULL,
        observacao TEXT,

        FOREIGN KEY (conta_id)
          REFERENCES contas(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_pagamentos_conta
      ON pagamentos (conta_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_pagamentos_data
      ON pagamentos (data_pagamento)
    ''');

    // Impede pagamentos acima do saldo restante.
    await db.execute('''
      CREATE TRIGGER impedir_pagamento_acima_saldo
      BEFORE INSERT ON pagamentos
      BEGIN
        SELECT CASE
          WHEN (
            SELECT COALESCE(SUM(valor_pago_centavos), 0)
            FROM pagamentos
            WHERE conta_id = NEW.conta_id
          ) + NEW.valor_pago_centavos > (
            SELECT valor_total_centavos
            FROM contas
            WHERE id = NEW.conta_id
          )
          THEN RAISE(
            ABORT,
            'Pagamento maior que o saldo restante'
          )
        END;
      END;
    ''');

    // Aplica a proteção também ao editar pagamentos.
    await db.execute('''
      CREATE TRIGGER impedir_edicao_pagamento_acima_saldo
      BEFORE UPDATE OF conta_id, valor_pago_centavos
      ON pagamentos
      BEGIN
        SELECT CASE
          WHEN (
            SELECT COALESCE(SUM(valor_pago_centavos), 0)
            FROM pagamentos
            WHERE conta_id = NEW.conta_id
              AND id != OLD.id
          ) + NEW.valor_pago_centavos > (
            SELECT valor_total_centavos
            FROM contas
            WHERE id = NEW.conta_id
          )
          THEN RAISE(
            ABORT,
            'Pagamento maior que o saldo restante'
          )
        END;
      END;
    ''');

    // Impede reduzir o valor da conta abaixo do total pago.
    await db.execute('''
      CREATE TRIGGER impedir_reducao_conta_abaixo_pago
      BEFORE UPDATE OF valor_total_centavos ON contas
      BEGIN
        SELECT CASE
          WHEN NEW.valor_total_centavos < (
            SELECT COALESCE(SUM(valor_pago_centavos), 0)
            FROM pagamentos
            WHERE conta_id = OLD.id
          )
          THEN RAISE(
            ABORT,
            'Valor da conta menor que o total pago'
          )
        END;
      END;
    ''');

    // 5. Configurações
    await db.execute('''
      CREATE TABLE configuracoes (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');

    // Categorias iniciais.
    final categorias = [
      ['Moradia', '#607D8B'],
      ['Água', '#2196F3'],
      ['Energia', '#FFC107'],
      ['Internet e telefone', '#9C27B0'],
      ['Alimentação', '#4CAF50'],
      ['Transporte', '#FF9800'],
      ['Saúde', '#E91E63'],
      ['Educação', '#3F51B5'],
      ['Lazer', '#00BCD4'],
      ['Outros', '#9E9E9E'],
    ];

    final batch = db.batch();

    for (final categoria in categorias) {
      batch.insert('categorias', {
        'nome': categoria[0],
        'cor': categoria[1],
        'padrao': 1,
      });
    }

    await batch.commit(noResult: true);
  }

  // Futuras atualizações da estrutura do banco.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // As migrações serão adicionadas conforme o banco evoluir.
  }
}
