# Domus

Aplicativo de gerenciamento de contas domésticas desenvolvido com Flutter e Dart, com o objetivo de facilitar o controle e a organização das despesas de uma residência.

## Sobre o projeto

O Domus permite cadastrar e acompanhar contas domésticas em um único lugar, facilitando o controle dos valores, vencimentos e pagamentos.

O aplicativo utiliza banco de dados SQLite para armazenar as informações localmente no dispositivo, permitindo que o usuário gerencie suas despesas de maneira simples e organizada, sem depender de um servidor externo.

## Funcionalidades

- Cadastro de contas domésticas.
- Edição e consulta dos detalhes das contas.
- Organização das contas por status: pendentes, atrasadas, parcialmente pagas e pagas.
- Filtros para facilitar a visualização das contas.
- Registro de pagamentos totais e parciais.
- Histórico de pagamentos por conta.
- Cadastro de contas recorrentes mensais e anuais.
- Geração automática de novas contas recorrentes ao abrir o aplicativo.
- Proteção contra exclusão de contas que possuem pagamentos registrados.
- Resumo mensal das despesas.
- Gráficos para visualização dos valores e da situação das contas.
- Navegação entre diferentes meses para consultar os dados financeiros.

## Tecnologias utilizadas

- **Flutter:** desenvolvimento da interface e estrutura do aplicativo.
- **Dart:** linguagem de programação.
- **SQLite:** armazenamento local dos dados.
- **sqflite:** integração do banco de dados SQLite com Flutter.
- **path:** manipulação de caminhos utilizados pelo banco de dados.
- **flutter_lints:** conjunto de regras para análise estática e boas práticas de código.
- **Git e GitHub:** controle de versão e hospedagem do código-fonte.

## Arquitetura do projeto

O projeto está organizado em duas partes principais: as telas da aplicação e a camada responsável pelo banco de dados.

```text
lib/
├── adicionar_conta.dart
├── contas.dart
├── detalhes_conta.dart
├── editar_conta.dart
├── main.dart
├── resumo_mensal.dart
├── tela_inicial.dart
│
└── database/
    ├── contas_repository.dart
    ├── database_helper.dart
    ├── pagamentos_repository.dart
    ├── recorrencias_gerador.dart
    └── recorrencias_repository.dart
```

### Organização dos arquivos

- **main.dart:** inicialização do aplicativo e geração de contas recorrentes na abertura.
- **tela_inicial.dart:** tela principal, com indicadores financeiros e próximas contas.
- **adicionar_conta.dart:** cadastro de novas contas e configuração de recorrências.
- **contas.dart:** listagem e filtragem das contas cadastradas.
- **detalhes_conta.dart:** visualização dos detalhes, pagamentos e histórico de cada conta.
- **editar_conta.dart:** edição dos dados de uma conta.
- **resumo_mensal.dart:** apresentação dos indicadores financeiros e gráficos mensais.

### Camada de banco de dados

Os arquivos da pasta `database/` concentram as operações de persistência e as regras relacionadas aos dados:

- **database_helper.dart:** criação e configuração do banco SQLite, tabelas, índices, relacionamentos e restrições.
- **contas_repository.dart:** cadastro, consulta, atualização, exclusão e resumo das contas.
- **pagamentos_repository.dart:** registro, consulta e exclusão de pagamentos.
- **recorrencias_repository.dart:** gerenciamento das regras de recorrência.
- **recorrencias_gerador.dart:** geração automática das contas recorrentes.

## Banco de dados

O Domus utiliza SQLite por meio da biblioteca `sqflite`, armazenando os dados localmente no dispositivo.

O banco possui cinco tabelas principais:

| Tabela | Responsabilidade |
|---|---|
| `categorias` | Armazenar as categorias das despesas. |
| `contas` | Armazenar as contas cadastradas. |
| `pagamentos` | Registrar os pagamentos realizados. |
| `recorrencias` | Armazenar as regras de contas recorrentes. |
| `configuracoes` | Armazenar configurações do aplicativo. |

### Relacionamentos

- Uma categoria pode estar associada a várias contas.
- Uma categoria pode estar associada a várias recorrências.
- Uma recorrência pode gerar várias contas.
- Uma conta pode possuir vários registros de pagamento.

O banco utiliza chaves primárias e estrangeiras para manter os relacionamentos e garantir a integridade dos dados.

Os valores financeiros são armazenados em centavos, utilizando números inteiros para evitar problemas de precisão em operações monetárias.

## Regras de negócio

- Uma conta pode receber pagamentos totais ou parciais.
- O valor pago não pode ultrapassar o valor total da conta.
- O valor total de uma conta não pode ser reduzido abaixo do valor já pago.
- Contas que possuem pagamentos registrados não podem ser excluídas.
- A última conta vinculada a uma recorrência ativa não pode ser excluída enquanto essa recorrência permanecer ativa.
- Contas recorrentes podem ter frequência mensal ou anual.
- Quando o dia configurado para uma recorrência não existir em determinado mês, é utilizado o último dia válido daquele mês.
- A geração de contas recorrentes acontece quando o aplicativo é aberto, sem execução em segundo plano.
- A desativação de uma recorrência interrompe novas gerações, mas mantém as contas que já foram criadas.

## Testes e validação

O projeto possui testes de widget e testes de integração para verificar o funcionamento da interface, das operações do banco de dados e das regras de negócio.

### Teste de widget

Verifica a inicialização do aplicativo e a presença de elementos principais da tela inicial.

Para executar:

```bash
flutter test
```

### Testes de integração

Os testes de integração verificam:

- Criação das tabelas e categorias padrão.
- Integridade dos relacionamentos e restrições do banco.
- Cadastro, consulta, atualização e exclusão de contas.
- Registro de pagamentos totais e parciais.
- Bloqueio de pagamentos acima do saldo.
- Atualização do saldo após exclusão de pagamentos.
- Cálculo do resumo mensal.
- Geração de contas recorrentes.
- Ajuste de datas em meses com diferentes quantidades de dias.
- Prevenção de duplicidade na geração de recorrências.

Para executar os testes de integração:

```bash
flutter test integration_test -d <id-do-dispositivo>
```

### Análise estática

O projeto utiliza `flutter_lints` para verificar possíveis problemas e incentivar boas práticas de programação.

Para executar a análise:

```bash
flutter analyze
```

## Como executar o projeto

### Pré-requisitos

- Flutter SDK instalado.
- Android Studio e Android SDK configurados.
- Emulador Android ou dispositivo conectado.

### Instalação

1. Clone o repositório:

```bash
git clone https://github.com/Richardsantos2703/domus.git
```

2. Entre na pasta do projeto:

```bash
cd domus
```

3. Instale as dependências:

```bash
flutter pub get
```

4. Execute o aplicativo:

```bash
flutter run
```