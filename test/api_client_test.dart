import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livro_caixa_app/api/api_client.dart';
import 'package:livro_caixa_app/models/movimento.dart';
import 'package:livro_caixa_app/util/format.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('normaliza a URL base', () {
    expect(ApiClient.normalizarBaseUrl('localhost:8080'), 'http://localhost:8080/api/v1');
    expect(ApiClient.normalizarBaseUrl('http://h:8080/'), 'http://h:8080/api/v1');
    expect(ApiClient.normalizarBaseUrl('https://h/api/v1'), 'https://h/api/v1');
  });

  test('envia token Bearer e lê movimentos paginados', () async {
    late http.Request recebido;
    final api = ApiClient(
      baseUrl: 'http://x',
      token: 'abc',
      httpClient: MockClient((req) async {
        recebido = req;
        return _json({
          'data': [
            {
              'id': 15,
              'data': '2026-11-25',
              'tipo': 'receita',
              'descricao': 'Venda',
              'valor': 1000.0,
              'categoria': {'id': 1, 'nome': 'Vendas'}
            }
          ],
          'meta': {'total': 1, 'pagina': 1, 'por_pagina': 50, 'paginas': 1}
        });
      }),
    );

    final p = await api.listarMovimentos(mes: 11, ano: 2026, tipo: TipoMovimento.receita);

    expect(recebido.headers['Authorization'], 'Bearer abc');
    expect(recebido.url.path, '/api/v1/movimentos');
    expect(recebido.url.queryParameters, containsPair('tipo', 'receita'));
    expect(recebido.url.queryParameters.containsKey('busca'), isFalse);
    expect(p.itens.single.valor, 1000.0);
    expect(p.itens.single.categoriaNome, 'Vendas');
    expect(p.temMais, isFalse);
  });

  test('serializa movimento no formato da API', () {
    final m = Movimento(
      data: DateTime(2026, 1, 5),
      tipo: TipoMovimento.despesa,
      descricao: 'Luz',
      valor: 123.456,
      categoriaId: 3,
    );
    expect(m.toJson(), {
      'data': '2026-01-05',
      'tipo': 'despesa',
      'descricao': 'Luz',
      'valor': 123.46,
      'categoria_id': 3,
    });
  });

  test('converte erro 422 em ApiException com detalhes', () async {
    final api = ApiClient(
      baseUrl: 'http://x',
      token: 't',
      httpClient: MockClient((_) async => _json({
            'error': {
              'status': 422,
              'message': 'Dados inválidos.',
              'details': {'valor': 'Informe um valor maior que zero.'}
            }
          }, 422)),
    );

    await expectLater(
      api.criarCategoria(''),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 422)
          .having((e) => e.details['valor'], 'detalhe', contains('maior que zero'))),
    );
  });

  test('DELETE com 204 não falha', () async {
    final api = ApiClient(
        baseUrl: 'http://x', token: 't', httpClient: MockClient((_) async => http.Response('', 204)));
    await api.removerMovimento(1);
  });

  test('parseValor aceita formatos pt-BR e en', () {
    expect(parseValor('1.000,50'), 1000.5);
    expect(parseValor(r'R$ 1.234,5'), 1234.5);
    expect(parseValor('1000.50'), 1000.5);
    expect(parseValor('1.000'), 1000);
    expect(parseValor('10'), 10);
    expect(parseValor('abc'), isNull);
  });
}
