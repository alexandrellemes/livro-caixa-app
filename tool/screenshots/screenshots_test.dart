// Gera os prints do README em docs/screenshots/ com dados fictícios (API simulada).
//
//   flutter test --update-goldens tool/screenshots/screenshots_test.dart
//
// Fica fora de test/ para não rodar no `flutter test` comum.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:livro_caixa_app/main.dart';
import 'package:livro_caixa_app/session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tamanho = Size(390, 844); // tela de celular, em pixels lógicos
const _escala = 2.0;

// ------------------------------------------------------------ dados fictícios

final _hoje = DateTime.now();
String _data(int dia) =>
    '${_hoje.year}-${_hoje.month.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}';

const _categorias = [
  {'id': 1, 'nome': 'Vendas'},
  {'id': 2, 'nome': 'Serviços'},
  {'id': 3, 'nome': 'Aluguel'},
  {'id': 4, 'nome': 'Energia elétrica'},
  {'id': 5, 'nome': 'Internet'},
  {'id': 6, 'nome': 'Fornecedores'},
  {'id': 7, 'nome': 'Salários'},
];

Map<String, dynamic> _mov(int id, int dia, String tipo, String descricao, double valor, int cat) => {
      'id': id,
      'data': _data(dia),
      'tipo': tipo,
      'descricao': descricao,
      'valor': valor,
      'categoria': {'id': cat, 'nome': _categorias[cat - 1]['nome']},
    };

final _movimentos = [
  _mov(12, 24, 'receita', 'Venda balcão', 1250.00, 1),
  _mov(11, 22, 'despesa', 'Conta de luz', 412.37, 4),
  _mov(10, 20, 'receita', 'Manutenção de computador', 680.00, 2),
  _mov(9, 18, 'despesa', 'Compra de mercadorias', 2340.90, 6),
  _mov(8, 15, 'receita', 'Venda atacado', 4800.00, 1),
  _mov(7, 12, 'despesa', 'Internet fibra', 129.90, 5),
  _mov(6, 10, 'receita', 'Instalação de rede', 950.00, 2),
  _mov(5, 8, 'despesa', 'Folha de pagamento', 3200.00, 7),
  _mov(4, 5, 'despesa', 'Aluguel da loja', 1800.00, 3),
  _mov(3, 3, 'receita', 'Venda balcão', 870.50, 1),
  _mov(2, 2, 'receita', 'Consultoria', 1500.00, 2),
  _mov(1, 1, 'despesa', 'Fornecedor de embalagens', 315.00, 6),
];

double _soma(String tipo) => _movimentos
    .where((m) => m['tipo'] == tipo)
    .fold(0.0, (s, m) => s + (m['valor'] as double));

Map<String, dynamic> _log(int id, int minutos, String nivel, String acao, String msg,
        {String? entidade, int? entidadeId, String usuario = 'admin'}) =>
    {
      'id': id,
      'data_hora': _hoje.subtract(Duration(minutes: minutos)).toUtc().toIso8601String(),
      'nivel': nivel,
      'acao': acao,
      'mensagem': msg,
      'entidade': entidade,
      'entidade_id': entidadeId?.toString(),
      'usuario': usuario,
      'ip': '192.168.0.10',
    };

final _logs = [
  _log(58, 3, 'info', 'movimento.criar', 'Movimento #12 criado.', entidade: 'movimento', entidadeId: 12),
  _log(57, 15, 'info', 'movimento.editar', 'Movimento #11 alterado.', entidade: 'movimento', entidadeId: 11),
  _log(56, 42, 'warning', 'api.login_falha', 'Falha ao gerar token da API: credenciais inválidas.',
      usuario: 'viewer'),
  _log(55, 60, 'info', 'api.token_criar', 'Token de API "app-flutter" criado.'),
  _log(54, 180, 'info', 'categoria.criar', 'Categoria #7 criada.', entidade: 'categoria', entidadeId: 7),
  _log(53, 300, 'warning', 'auth.acesso_negado', "API: acesso negado, perfil 'admin' exigido.",
      usuario: 'viewer'),
  _log(52, 1440, 'error', 'app.excecao', 'Falha ao enviar e-mail de recuperação de senha.'),
  _log(51, 1500, 'info', 'auth.login', 'Login realizado.'),
];

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

final _api = MockClient((req) async {
  final rota = req.url.path.replaceFirst('/api/v1', '');
  final q = req.url.queryParameters;

  switch ((req.method, rota)) {
    case ('POST', '/auth/token'):
      return _json({
        'data': {'token': 'demo', 'tipo': 'Bearer', 'usuario': 'admin', 'perfil': 'admin'}
      }, 201);
    case ('GET', '/auth/me'):
      return _json({
        'data': {'usuario': 'admin', 'perfil': 'admin', 'token_id': 3}
      });
    case ('GET', '/auth/tokens'):
      final agora = _hoje.toIso8601String();
      final expira = _hoje.add(const Duration(days: 90)).toIso8601String();
      return _json({
        'data': [
          {'id': 3, 'nome': 'app-flutter', 'criado_em': agora, 'expira_em': expira, 'ultimo_uso': agora, 'revogado_em': null},
          {'id': 2, 'nome': 'integracao-erp', 'criado_em': agora, 'expira_em': expira, 'ultimo_uso': null, 'revogado_em': null},
          {'id': 1, 'nome': 'teste', 'criado_em': agora, 'expira_em': expira, 'ultimo_uso': agora, 'revogado_em': agora},
        ]
      });
    case ('GET', '/categorias'):
      return _json({'data': _categorias});
    case ('GET', '/movimentos'):
      final porPagina = int.parse(q['por_pagina'] ?? '50');
      final itens = _movimentos.take(porPagina).toList();
      return _json({
        'data': itens,
        'meta': {'total': _movimentos.length, 'pagina': 1, 'por_pagina': porPagina, 'paginas': 1},
      });
    case ('GET', '/resumo'):
      final e = _soma('receita'), s = _soma('despesa');
      return _json({
        'data': {
          'mes': int.parse(q['mes']!),
          'ano': int.parse(q['ano']!),
          'mensal': {'entradas': e, 'saidas': s, 'resultado': e - s},
          'geral': {'entradas': 98450.75, 'saidas': 71230.40, 'resultado': 27220.35},
        }
      });
    case ('GET', '/logs'):
      return _json({
        'data': _logs,
        'meta': {'total': _logs.length, 'pagina': 1, 'por_pagina': 50, 'paginas': 1},
      });
    case ('GET', '/logs/58'):
      return _json({
        'data': {
          ..._logs.first,
          'contexto': {
            'depois': {
              'data': _data(24),
              'tipo': 'receita',
              'descricao': 'Venda balcão',
              'valor': '1250,00',
              'categoria_id': 1,
            },
          },
          'requisicao': {'metodo': 'POST', 'uri': '/api/v1/movimentos', 'user_agent': 'Dart/3.14 (dart:io)'},
        }
      });
  }
  return _json({
    'error': {'status': 404, 'message': 'Recurso não encontrado.'}
  }, 404);
});

// ------------------------------------------------------------------- helpers

Future<void> _carregarFontes() async {
  // Sem isso o teste desenha texto e ícones como retângulos (fonte Ahem).
  final raiz = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.parent.path;
  final dir = '$raiz/bin/cache/artifacts/material_fonts';

  Future<void> carregar(String familia, List<String> arquivos) async {
    final loader = FontLoader(familia);
    for (final a in arquivos) {
      loader.addFont(File('$dir/$a').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  }

  await carregar('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ]);
  await carregar('MaterialIcons', ['MaterialIcons-Regular.otf']);

  // Fonte monoespaçada do bloco "Contexto" dos logs (no aparelho vem do sistema).
  final mono = FontLoader('monospace')
    ..addFont(File('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf')
        .readAsBytes()
        .then((b) => ByteData.view(b.buffer)));
  await mono.load();
}

Future<void> _abrirApp(WidgetTester tester, {bool logado = true, bool escuro = false}) async {
  tester.view.physicalSize = _tamanho * _escala;
  tester.view.devicePixelRatio = _escala;
  tester.platformDispatcher.platformBrightnessTestValue = escuro ? Brightness.dark : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  // Por padrão o flutter_test troca sombras por contornos pretos sólidos.
  debugDisableShadows = false;
  addTearDown(() => debugDisableShadows = true);

  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'base_url': 'http://192.168.0.10:8080/api/v1',
    if (logado) ...{'token': 'demo', 'usuario': 'admin', 'perfil': 'admin'},
  });

  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => Session(httpClient: _api)..carregar(),
    child: const LivroCaixaApp(),
  ));
  await tester.pumpAndSettle();
}

Future<void> _aba(WidgetTester tester, String nome) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(nome)));
  await tester.pumpAndSettle();
}

Future<void> _print(String nome) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('../../docs/screenshots/$nome.png'));

// --------------------------------------------------------------------- prints

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('pt_BR');
    await _carregarFontes();
  });

  testWidgets('login', (tester) async {
    await _abrirApp(tester, logado: false);
    await tester.enterText(find.widgetWithText(TextFormField, 'Usuário'), 'admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'segredo123');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _print('01-login');
  });

  testWidgets('resumo', (tester) async {
    await _abrirApp(tester);
    await _print('02-resumo');
  });

  testWidgets('movimentos', (tester) async {
    await _abrirApp(tester);
    await _aba(tester, 'Movimentos');
    await _print('03-movimentos');
  });

  testWidgets('novo movimento', (tester) async {
    await _abrirApp(tester);
    await _aba(tester, 'Movimentos');
    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'), 'Venda balcão');
    await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '350,00');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vendas').last);
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _print('04-novo-movimento');
  });

  testWidgets('categorias', (tester) async {
    await _abrirApp(tester);
    await _aba(tester, 'Categorias');
    await _print('05-categorias');
  });

  testWidgets('logs', (tester) async {
    await _abrirApp(tester);
    await _aba(tester, 'Logs');
    await _print('06-logs');
  });

  testWidgets('detalhe do log', (tester) async {
    await _abrirApp(tester);
    await _aba(tester, 'Logs');
    await tester.tap(find.text('Movimento #12 criado.'));
    await tester.pumpAndSettle();
    await _print('07-log-detalhe');
  });

  testWidgets('conta', (tester) async {
    await _abrirApp(tester);
    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();
    await _print('08-conta');
  });

  testWidgets('resumo (tema escuro)', (tester) async {
    await _abrirApp(tester, escuro: true);
    await _print('09-resumo-escuro');
  });
}
