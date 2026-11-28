
import 'package:flutter/material.dart';

import 'database/contas_repository.dart';
import 'database/database_helper.dart';
import 'database/recorrencias_repository.dart';

class TelaEditarConta extends StatefulWidget {
  final int contaId;

  const TelaEditarConta({super.key, required this.contaId});

  @override
  State<TelaEditarConta> createState() => _TelaEditarContaState();
}

class _TelaEditarContaState extends State<TelaEditarConta> {
  final ContasRepository _repository = ContasRepository();
  final RecorrenciasRepository _recorrenciasRepository =
      RecorrenciasRepository();

  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();

  DateTime? _vencimento;
  int? _categoriaId;
  int _valorPagoCentavos = 0;

  int? _recorrenciaId;
  bool _recorrenciaAtiva = false;
  bool _recorrenciaAtivaOriginal = false;
  String? _frequenciaRecorrencia;
  String? _frequenciaRecorrenciaOriginal;

  List<Map<String, Object?>> _categorias = [];

  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  ColorScheme get _cores => Theme.of(context).colorScheme;

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

      final recorrenciaId =
          (resultado['recorrencia_id'] as num?)?.toInt();

      final recorrencia = recorrenciaId == null
          ? null
          : await _recorrenciasRepository.buscarPorId(recorrenciaId);

      final recorrenciaAtiva =
          (recorrencia?['ativa'] as num?)?.toInt() == 1;

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
        _descricaoController.text =
            resultado['descricao'] as String? ?? '';

        _categoriaId = resultado['categoria_id'] as int;

        _valorPagoCentavos =
            (resultado['valor_pago_centavos'] as num?)?.toInt() ?? 0;

        _vencimento = DateTime(
          int.parse(partes[0]),
          int.parse(partes[1]),
          int.parse(partes[2]),
        );

        _recorrenciaId = recorrencia == null ? null : recorrenciaId;
        _recorrenciaAtiva = recorrenciaAtiva;
        _recorrenciaAtivaOriginal = recorrenciaAtiva;

        _frequenciaRecorrencia =
            recorrencia?['frequencia'] as String?;
        _frequenciaRecorrenciaOriginal = _frequenciaRecorrencia;

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
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios.'),
        ),
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

      if (_recorrenciaId != null) {
        if (_frequenciaRecorrencia != _frequenciaRecorrenciaOriginal) {
          if (_frequenciaRecorrencia == null) {
            throw Exception('Selecione uma frequência válida.');
          }

          await _recorrenciasRepository.atualizar(
            _recorrenciaId!,
            {
              'frequencia': _frequenciaRecorrencia,
              'mes_vencimento': _frequenciaRecorrencia == 'anual'
                  ? _vencimento!.month
                  : null,
            },
          );
        }

        if (_recorrenciaAtiva != _recorrenciaAtivaOriginal) {
          if (_recorrenciaAtiva) {
            await _recorrenciasRepository.ativar(_recorrenciaId!);
          } else {
            await _recorrenciasRepository.desativar(_recorrenciaId!);
          }
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar: $e')),
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
      fillColor: _cores.surfaceContainerHighest.withValues(alpha: 0.35),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: _cores.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: _cores.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: _cores.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: _cores.error, width: 1.5),
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
        color: _cores.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cores.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _cores.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icone,
                  color: _cores.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: _cores.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: _cores.onSurfaceVariant,
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
        Text(
          'Data de vencimento',
          style: TextStyle(
            color: _cores.onSurfaceVariant,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: _cores.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _cores.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: _cores.primary,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatarDataExibicao(_vencimento),
                    style: TextStyle(
                      color: _cores.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _cores.onSurfaceVariant,
                ),
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
        color: _cores.primaryContainer,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _cores.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: _cores.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta conta já possui ${_formatarValor(_valorPagoCentavos)} '
              'em pagamentos. O valor total não pode ser menor que '
              'essa quantia.',
              style: TextStyle(
                color: _cores.onPrimaryContainer,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSecaoRecorrencia() {
    if (_recorrenciaId == null) {
      return const SizedBox.shrink();
    }

    final frequencia = _frequenciaRecorrencia == 'mensal'
        ? 'Mensal'
        : 'Anual';

    return _construirSecao(
      icone: Icons.repeat,
      titulo: 'Recorrência',
      subtitulo: 'Controle a geração automática de novas contas',
      children: [
        DropdownButtonFormField<String>(
          initialValue: _frequenciaRecorrencia,
          isExpanded: true,
          decoration: _decoracaoCampo(
            label: 'Frequência',
            prefixIcon: Icon(
              Icons.calendar_month_outlined,
              color: _cores.onSurfaceVariant,
            ),
          ),
          items: const [
            DropdownMenuItem<String>(
              value: 'mensal',
              child: Text('Mensal'),
            ),
            DropdownMenuItem<String>(
              value: 'anual',
              child: Text('Anual'),
            ),
          ],
          onChanged: _salvando
              ? null
              : (value) {
                  if (value == null) return;

                  setState(() {
                    _frequenciaRecorrencia = value;
                  });
                },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Gerar novas contas automaticamente',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _recorrenciaAtiva
                ? 'Ativada ($frequencia). Novas contas serão geradas conforme a frequência.'
                : 'Desativada. Nenhuma nova conta será gerada.',
          ),
          value: _recorrenciaAtiva,
          onChanged: _salvando
              ? null
              : (value) {
                  setState(() {
                    _recorrenciaAtiva = value;
                  });
                },
        ),
        const SizedBox(height: 8),
        Text(
          'Desativar a recorrência não apaga contas já geradas nem '
          'seus pagamentos. Você poderá excluir contas normalmente, '
          'respeitando as regras de pagamentos registrados.',
          style: TextStyle(
            color: _cores.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _construirTelaErro() {
    return Scaffold(
      backgroundColor: _cores.surface,
      appBar: AppBar(
        title: const Text('Editar conta'),
        backgroundColor: _cores.surface,
        foregroundColor: _cores.onSurface,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: _cores.error,
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                'Não foi possível carregar a conta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _cores.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _erro ?? 'Ocorreu um erro inesperado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _cores.onSurfaceVariant,
                  fontSize: 13,
                ),
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
        backgroundColor: _cores.surface,
        appBar: AppBar(
          title: const Text('Editar conta'),
          backgroundColor: _cores.surface,
          foregroundColor: _cores.onSurface,
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(color: _cores.primary),
        ),
      );
    }

    if (_erro != null) {
      return _construirTelaErro();
    }

    return Scaffold(
      backgroundColor: _cores.surface,
      appBar: AppBar(
        title: const Text(
          'Editar conta',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _cores.surface,
        foregroundColor: _cores.onSurface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          children: [
            Text(
              'Atualize sua conta',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: _cores.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Altere as informações necessárias e salve as mudanças.',
              style: TextStyle(
                color: _cores.onSurfaceVariant,
                fontSize: 13,
              ),
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
                    prefixIcon: Icon(
                      Icons.edit_outlined,
                      color: _cores.onSurfaceVariant,
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
                    prefixIcon: Icon(
                      Icons.category_outlined,
                      color: _cores.onSurfaceVariant,
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
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: _cores.onSurfaceVariant,
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
            if (_recorrenciaId != null) ...[
              const SizedBox(height: 16),
              _construirSecaoRecorrencia(),
            ],
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
                    prefixIcon: Icon(
                      Icons.description_outlined,
                      color: _cores.onSurfaceVariant,
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
                  backgroundColor: _cores.primary,
                  foregroundColor: _cores.onPrimary,
                  disabledBackgroundColor:
                      _cores.onSurface.withValues(alpha: 0.12),
                  disabledForegroundColor:
                      _cores.onSurface.withValues(alpha: 0.38),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _salvando
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: _cores.onPrimary,
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