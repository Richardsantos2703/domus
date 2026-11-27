
import 'package:flutter/material.dart';

import 'tema_controller.dart';

class TelaConfiguracoes extends StatelessWidget {
  const TelaConfiguracoes({super.key});

  Future<void> _alterarTema(
    BuildContext context,
    String tema,
  ) async {
    try {
      await temaController.alterarTema(tema);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a preferência de tema.'),
        ),
      );
    }
  }

  Widget _construirOpcaoTema({
    required String titulo,
    required String descricao,
    required IconData icone,
    required String valor,
    required String selecionado,
  }) {
    return RadioListTile<String>(
      value: valor,
      selected: valor == selecionado,
      secondary: Icon(icone),
      title: Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(descricao),
      activeColor: Colors.blue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _construirSecao({
    required BuildContext context,
    required String titulo,
    required IconData icone,
    required Widget conteudo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                icone,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 9),
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: conteudo,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: AnimatedBuilder(
        animation: temaController,
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Personalize o Domus de acordo com sua preferência.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              _construirSecao(
                context: context,
                titulo: 'Aparência',
                icone: Icons.palette_outlined,
                conteudo: RadioGroup<String>(
                  groupValue: temaController.temaAtual,
                  onChanged: (novoTema) {
                    if (novoTema != null) {
                      _alterarTema(context, novoTema);
                    }
                  },
                  child: Column(
                    children: [
                      _construirOpcaoTema(
                        titulo: 'Automático',
                        descricao: 'Acompanhar o tema do dispositivo.',
                        icone: Icons.brightness_auto_outlined,
                        valor: 'automatico',
                        selecionado: temaController.temaAtual,
                      ),
                      const Divider(height: 1),
                      _construirOpcaoTema(
                        titulo: 'Claro',
                        descricao: 'Utilizar sempre o tema claro.',
                        icone: Icons.light_mode_outlined,
                        valor: 'claro',
                        selecionado: temaController.temaAtual,
                      ),
                      const Divider(height: 1),
                      _construirOpcaoTema(
                        titulo: 'Escuro',
                        descricao: 'Utilizar sempre o tema escuro.',
                        icone: Icons.dark_mode_outlined,
                        valor: 'escuro',
                        selecionado: temaController.temaAtual,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _construirSecao(
                context: context,
                titulo: 'Sobre',
                icone: Icons.info_outline,
                conteudo: Column(
                  children: [
                    const ListTile(
                      leading: Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: Text(
                        'Domus',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Controle suas contas domésticas em um só lugar.',
                      ),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.code),
                      title: Text('Versão'),
                      subtitle: Text('Em desenvolvimento'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'Domus • Controle de contas',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
