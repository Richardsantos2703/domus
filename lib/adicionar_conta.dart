import 'package:flutter/material.dart';

import 'database/database_helper.dart';

class TelaAdicionarConta extends StatefulWidget {
  const TelaAdicionarConta({super.key});

  @override
  State<TelaAdicionarConta> createState() => _TelaAdicionarContaState();
}

class _TelaAdicionarContaState extends State<TelaAdicionarConta> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();

  static const Color azulPrincipal = Color(0xFF2563EB);
  static const Color fundo = Color(0xFFF5F7FB);

  DateTime? _vencimento;
  int? _categoriaId;

  String _recorrencia = 'Não se repete';
  bool _salvando = false;

  List<Map<String, Object?>> _categorias = [];

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarCategorias() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final resultado = await db.query(
        'categorias',
        columns: ['id', 'nome'],
        orderBy: 'nome ASC',
      );

      if (!mounted) return;

      setState(() {
        _categorias = resultado;

        if (resultado.isNotEmpty) {
          _categoriaId = resultado.first['id'] as int;
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar categorias: $e')),
      );
    }
  }

  String _formatarDataBanco(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  String _formatarDataExibicao(DateTime? data) {
    if (data == null) {
      return 'Selecionar vencimento';
    }

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  int _converterParaCentavos(String valor) {
    var limpo = valor.replaceAll('R\$', '').replaceAll(' ', '').trim();

    if (limpo.isEmpty) {
      throw FormatException('Valor vazio');
    }

    final temPonto = limpo.contains('.');
    final temVirgula = limpo.contains(',');

    if (temPonto && temVirgula) {
      final ultimoPonto = limpo.lastIndexOf('.');
      final ultimaVirgula = limpo.lastIndexOf(',');

      if (ultimoPonto > ultimaVirgula) {
        limpo = limpo.replaceAll(',', '');
      } else {
        limpo = limpo.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (temPonto || temVirgula) {
      final separador = temPonto ? '.' : ',';
      final partes = limpo.split(separador);

      if (partes.length == 2 && partes[1].isNotEmpty && partes[1].length <= 2) {
        limpo = '${partes[0]}.${partes[1]}';
      } else {
        limpo = limpo.replaceAll(separador, '');
      }
    }

    final numero = double.parse(limpo);

    return (numero * 100).round();
  }

  Future<void> _selecionarVencimento() async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _vencimento ?? hoje,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecione o vencimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (data != null) {
      setState(() {
        _vencimento = data;
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vencimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data de vencimento.')),
      );

      return;
    }

    if (_categoriaId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione uma categoria.')));

      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final nome = _nomeController.text.trim();

      final valorCentavos = _converterParaCentavos(_valorController.text);

      if (valorCentavos <= 0) {
        throw Exception('O valor precisa ser maior que zero.');
      }

      final dataVencimento = _formatarDataBanco(_vencimento!);

      final descricao = _descricaoController.text.trim();

      await db.transaction((txn) async {
        int? recorrenciaId;

        if (_recorrencia != 'Não se repete') {
          final frequencia = _recorrencia == 'Mensal' ? 'mensal' : 'anual';

          recorrenciaId = await txn.insert('recorrencias', {
            'nome': nome,
            'valor_previsto_centavos': valorCentavos,
            'categoria_id': _categoriaId,
            'frequencia': frequencia,
            'dia_vencimento': _vencimento!.day,
            'mes_vencimento': frequencia == 'anual' ? _vencimento!.month : null,
            'descricao': descricao.isEmpty ? null : descricao,
            'ativa': 1,
            'criada_em': DateTime.now().toIso8601String(),
          });
        }

        await txn.insert('contas', {
          'nome': nome,
          'valor_total_centavos': valorCentavos,
          'categoria_id': _categoriaId,
          'recorrencia_id': recorrenciaId,
          'data_vencimento': dataVencimento,
          'descricao': descricao.isEmpty ? null : descricao,
          'criada_em': DateTime.now().toIso8601String(),
        });
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível cadastrar a conta: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  InputDecoration _decoracaoCampo({
    required String label,
    String? hint,
    String? prefixText,
    IconData? icone,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: icone == null ? null : Icon(icone),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: azulPrincipal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  Widget _construirSecao({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required List<Widget> campos,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: azulPrincipal, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...campos,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Adicionar conta',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF475569)),
      ),
      body: _categorias.isEmpty
          ? const Center(child: CircularProgressIndicator(color: azulPrincipal))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  const Text(
                    'Nova conta',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Preencha os dados para organizar uma nova despesa.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 22),

                  _construirSecao(
                    titulo: 'Informações da conta',
                    subtitulo: 'Identificação e valor da despesa',
                    icone: Icons.receipt_long_outlined,
                    campos: [
                      TextFormField(
                        controller: _nomeController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoracaoCampo(
                          label: 'Nome da conta',
                          hint: 'Ex.: Conta de água',
                          icone: Icons.edit_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o nome da conta.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _valorController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _decoracaoCampo(
                          label: 'Valor',
                          prefixText: 'R\$ ',
                          hint: '0,00',
                          icone: Icons.attach_money,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o valor.';
                          }

                          try {
                            if (_converterParaCentavos(value) <= 0) {
                              return 'Informe um valor maior que zero.';
                            }
                          } catch (_) {
                            return 'Informe um valor válido.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _categoriaId,
                        isExpanded: true,
                        decoration: _decoracaoCampo(
                          label: 'Categoria',
                          icone: Icons.category_outlined,
                        ),
                        items: _categorias.map((categoria) {
                          return DropdownMenuItem<int>(
                            value: categoria['id'] as int,
                            child: Text(categoria['nome'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _categoriaId = value;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _construirSecao(
                    titulo: 'Datas e recorrência',
                    subtitulo: 'Defina quando a conta vence',
                    icone: Icons.calendar_month_outlined,
                    campos: [
                      InkWell(
                        onTap: _selecionarVencimento,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _vencimento == null
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: azulPrincipal,
                                size: 21,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Data de vencimento',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatarDataExibicao(_vencimento),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _vencimento == null
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _recorrencia,
                        isExpanded: true,
                        decoration: _decoracaoCampo(
                          label: 'Recorrência',
                          icone: Icons.repeat,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Não se repete',
                            child: Text('Não se repete'),
                          ),
                          DropdownMenuItem(
                            value: 'Mensal',
                            child: Text('Mensal'),
                          ),
                          DropdownMenuItem(
                            value: 'Anual',
                            child: Text('Anual'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _recorrencia = value;
                            });
                          }
                        },
                      ),
                      if (_recorrencia != 'Não se repete') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: azulPrincipal,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Uma nova conta será gerada automaticamente conforme a recorrência configurada.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  _construirSecao(
                    titulo: 'Descrição',
                    subtitulo: 'Informações adicionais (opcional)',
                    icone: Icons.notes_outlined,
                    campos: [
                      TextFormField(
                        controller: _descricaoController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        decoration: _decoracaoCampo(
                          label: 'Descrição',
                          hint: 'Adicione detalhes sobre esta conta...',
                          icone: Icons.description_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulPrincipal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: azulPrincipal.withValues(
                          alpha: 0.5,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined, size: 20),
                                SizedBox(width: 9),
                                Text(
                                  'Salvar conta',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
