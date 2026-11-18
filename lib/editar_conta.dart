import 'package:flutter/material.dart';

import 'database/contas_repository.dart';
import 'database/database_helper.dart';

class TelaEditarConta extends StatefulWidget {
  final int contaId;

  const TelaEditarConta({super.key, required this.contaId});

  @override
  State<TelaEditarConta> createState() => _TelaEditarContaState();
}

class _TelaEditarContaState extends State<TelaEditarConta> {
  final ContasRepository _repository = ContasRepository();

  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();

  DateTime? _vencimento;
  int? _categoriaId;

  int _valorPagoCentavos = 0;

  List<Map<String, Object?>> _categorias = [];

  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  static const Color _azul = Color(0xFF2563EB);
  static const Color _fundo = Color(0xFFF5F7FB);
  static const Color _texto = Color(0xFF172033);

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final categorias = await db.query(
        'categorias',
        columns: ['id', 'nome'],
        orderBy: 'nome ASC',
      );

      final resultado = await _repository.buscarPorId(widget.contaId);

      if (resultado == null) {
        throw Exception('Conta não encontrada.');
      }

      final partes = (resultado['data_vencimento'] as String).split('-');

      if (partes.length != 3) {
        throw Exception('Data de vencimento inválida.');
      }

      if (!mounted) return;

      setState(() {
        _categorias = categorias;
        _nomeController.text = resultado['nome'] as String;
        _valorController.text = _formatarValor(
          (resultado['valor_total_centavos'] as num).toInt(),
        );
        _descricaoController.text = resultado['descricao'] as String? ?? '';

        _categoriaId = resultado['categoria_id'] as int;

        _valorPagoCentavos =
            (resultado['valor_pago_centavos'] as num?)?.toInt() ?? 0;

        _vencimento = DateTime(
          int.parse(partes[0]),
          int.parse(partes[1]),
          int.parse(partes[2]),
        );

        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  String _formatarValor(int centavos) {
    final reais = centavos ~/ 100;
    final centavosFormatados = (centavos % 100).toString().padLeft(2, '0');

    return '$reais,$centavosFormatados';
  }

  int _converterParaCentavos(String valor) {
    final limpo = valor
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return (double.parse(limpo) * 100).round();
  }

  String _formatarDataBanco(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  String _formatarDataExibicao(DateTime? data) {
    if (data == null) return 'Selecionar vencimento';

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  Future<void> _selecionarVencimento() async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _vencimento ?? hoje,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecione o vencimento',
    );

    if (data != null && mounted) {
      setState(() {
        _vencimento = data;
      });
    }
  }

  String? _validarValor(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o valor.';
    }

    try {
      final valorCentavos = _converterParaCentavos(value);

      if (valorCentavos <= 0) {
        return 'Informe um valor maior que zero.';
      }

      if (valorCentavos < _valorPagoCentavos) {
        return 'O valor não pode ser menor que o total já pago '
            '(${_formatarValor(_valorPagoCentavos)}).';
      }
    } catch (_) {
      return 'Informe um valor válido.';
    }

    return null;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vencimento == null || _categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios.')),
      );
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      final valorCentavos = _converterParaCentavos(_valorController.text);

      if (valorCentavos <= 0) {
        throw Exception('O valor precisa ser maior que zero.');
      }

      if (valorCentavos < _valorPagoCentavos) {
        throw Exception(
          'O valor não pode ser menor que o total já pago '
          '(${_formatarValor(_valorPagoCentavos)}).',
        );
      }

      await _repository.atualizar(widget.contaId, {
        'nome': _nomeController.text.trim(),
        'valor_total_centavos': valorCentavos,
        'categoria_id': _categoriaId,
        'data_vencimento': _formatarDataBanco(_vencimento!),
        'descricao': _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível atualizar: $e')));
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
    String? prefixText,
    String? helperText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixIcon: prefixIcon,
      helperText: helperText,
      helperMaxLines: 2,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _azul, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  Widget _construirSecao({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: _azul, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _construirCampoData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data de vencimento',
          style: TextStyle(
            color: Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        InkWell(
          onTap: _selecionarVencimento,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: _azul,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatarDataExibicao(_vencimento),
                    style: const TextStyle(
                      color: _texto,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirAvisoPagamento() {
    if (_valorPagoCentavos <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: _azul, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta conta já possui ${_formatarValor(_valorPagoCentavos)} '
              'em pagamentos. O valor total não pode ser menor que '
              'essa quantia.',
              style: const TextStyle(
                color: Color(0xFF1E40AF),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTelaErro() {
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        title: const Text('Editar conta'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _texto,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFDC2626),
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                'Não foi possível carregar a conta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _texto,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _erro ?? 'Ocorreu um erro inesperado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        backgroundColor: _fundo,
        appBar: AppBar(
          title: const Text('Editar conta'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _texto,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: _azul)),
      );
    }

    if (_erro != null) {
      return _construirTelaErro();
    }

    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        title: const Text(
          'Editar conta',
          style: TextStyle(
            color: _texto,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _texto,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          children: [
            const Text(
              'Atualize sua conta',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: _texto,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Altere as informações necessárias e salve as mudanças.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 22),

            _construirSecao(
              icone: Icons.receipt_long_outlined,
              titulo: 'Informações da conta',
              subtitulo: 'Nome e categoria da despesa',
              children: [
                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoracaoCampo(
                    label: 'Nome da conta',
                    prefixIcon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da conta.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  initialValue: _categoriaId,
                  isExpanded: true,
                  decoration: _decoracaoCampo(
                    label: 'Categoria',
                    prefixIcon: const Icon(
                      Icons.category_outlined,
                      color: Color(0xFF64748B),
                    ),
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
              icone: Icons.payments_outlined,
              titulo: 'Valor e vencimento',
              subtitulo: 'Defina o valor total e a data limite',
              children: [
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoracaoCampo(
                    label: 'Valor total',
                    prefixText: 'R\$ ',
                    helperText:
                        'O valor não pode ser inferior ao total já pago.',
                    prefixIcon: const Icon(
                      Icons.attach_money,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  validator: _validarValor,
                ),
                const SizedBox(height: 18),
                _construirAvisoPagamento(),
                if (_valorPagoCentavos > 0) const SizedBox(height: 18),
                _construirCampoData(),
              ],
            ),

            const SizedBox(height: 16),

            _construirSecao(
              icone: Icons.notes_outlined,
              titulo: 'Descrição',
              subtitulo: 'Informações adicionais sobre a conta',
              children: [
                TextFormField(
                  controller: _descricaoController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  decoration: _decoracaoCampo(
                    label: 'Descrição (opcional)',
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFF64748B),
                    ),
                  ).copyWith(alignLabelWithHint: true),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF93C5FD),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _salvando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
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
                            'Salvar alterações',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
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
