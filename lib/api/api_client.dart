import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/categoria.dart';
import '../models/log_entry.dart';
import '../models/movimento.dart';
import '../models/paginado.dart';
import '../models/resumo.dart';
import '../models/token_info.dart';

/// Erro devolvido pela API: {"error": {"status", "message", "details"}}.
class ApiException implements Exception {
  ApiException(this.status, this.message, [this.details = const {}]);

  final int status;
  final String message;
  final Map<String, String> details;

  bool get naoAutorizado => status == 401;

  /// Mensagem completa, incluindo os erros de validação por campo.
  String get descricao {
    if (details.isEmpty) return message;
    return '$message\n${details.entries.map((e) => '• ${e.key}: ${e.value}').join('\n')}';
  }

  @override
  String toString() => descricao;
}

/// Resultado de POST /auth/token.
class TokenGerado {
  TokenGerado({required this.token, required this.usuario, required this.perfil});

  final String token;
  final String usuario;
  final String perfil;
}

/// Cliente da API REST v1 do Livro Caixa.
class ApiClient {
  ApiClient({required String baseUrl, this.token, http.Client? httpClient})
      : baseUrl = normalizarBaseUrl(baseUrl),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  String? token;
  final http.Client _http;

  static const _timeout = Duration(seconds: 20);

  /// Aceita "localhost:8080", "http://host:8080" ou "http://host:8080/api/v1".
  static String normalizarBaseUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith(RegExp(r'https?://'))) u = 'http://$u';
    u = u.replaceAll(RegExp(r'/+$'), '');
    if (!u.endsWith('/api/v1')) u = '$u/api/v1';
    return u;
  }

  // ---------------------------------------------------------------- Auth

  Future<TokenGerado> gerarToken(String username, String password,
      {String nome = 'app-flutter', int expiraEmDias = 90}) async {
    final body = await _send('POST', '/auth/token', body: {
      'username': username,
      'password': password,
      'nome': nome,
      'expira_em_dias': expiraEmDias,
    }, autenticado: false);
    final d = body['data'] as Map<String, dynamic>;
    return TokenGerado(
      token: d['token'] as String,
      usuario: d['usuario'] as String,
      perfil: d['perfil'] as String? ?? 'viewer',
    );
  }

  Future<({String usuario, String perfil})> me() async {
    final d = (await _send('GET', '/auth/me'))['data'] as Map<String, dynamic>;
    return (usuario: d['usuario'] as String, perfil: d['perfil'] as String? ?? 'viewer');
  }

  Future<List<TokenInfo>> listarTokens() async {
    final d = (await _send('GET', '/auth/tokens'))['data'] as List;
    return d.map((e) => TokenInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> revogarTokenAtual() => _send('DELETE', '/auth/token');

  Future<void> revogarToken(int id) => _send('DELETE', '/auth/tokens/$id');

  // ---------------------------------------------------------- Categorias

  Future<List<Categoria>> listarCategorias({String? busca}) async {
    final d = (await _send('GET', '/categorias', query: {'busca': busca}))['data'] as List;
    return d.map((e) => Categoria.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Categoria> buscarCategoria(int id) async =>
      Categoria.fromJson((await _send('GET', '/categorias/$id'))['data'] as Map<String, dynamic>);

  Future<Categoria> criarCategoria(String nome) async => Categoria.fromJson(
      (await _send('POST', '/categorias', body: {'nome': nome}))['data'] as Map<String, dynamic>);

  Future<Categoria> atualizarCategoria(int id, String nome) async => Categoria.fromJson(
      (await _send('PUT', '/categorias/$id', body: {'nome': nome}))['data'] as Map<String, dynamic>);

  Future<void> removerCategoria(int id) => _send('DELETE', '/categorias/$id');

  // ---------------------------------------------------------- Movimentos

  Future<Paginado<Movimento>> listarMovimentos({
    int? mes,
    int? ano,
    int? categoriaId,
    TipoMovimento? tipo,
    String? busca,
    int pagina = 1,
    int porPagina = 50,
  }) async {
    final body = await _send('GET', '/movimentos', query: {
      'mes': mes?.toString(),
      'ano': ano?.toString(),
      'categoria_id': categoriaId?.toString(),
      'tipo': tipo?.api,
      'busca': busca,
      'pagina': '$pagina',
      'por_pagina': '$porPagina',
    });
    return Paginado.fromJson(body, Movimento.fromJson);
  }

  Future<Movimento> buscarMovimento(int id) async =>
      Movimento.fromJson((await _send('GET', '/movimentos/$id'))['data'] as Map<String, dynamic>);

  Future<Movimento> criarMovimento(Movimento m) async => Movimento.fromJson(
      (await _send('POST', '/movimentos', body: m.toJson()))['data'] as Map<String, dynamic>);

  Future<Movimento> atualizarMovimento(Movimento m) async => Movimento.fromJson(
      (await _send('PUT', '/movimentos/${m.id}', body: m.toJson()))['data'] as Map<String, dynamic>);

  Future<void> removerMovimento(int id) => _send('DELETE', '/movimentos/$id');

  // -------------------------------------------------------------- Resumo

  Future<Resumo> resumo({required int mes, required int ano}) async => Resumo.fromJson(
      (await _send('GET', '/resumo', query: {'mes': '$mes', 'ano': '$ano'}))['data']
          as Map<String, dynamic>);

  // ---------------------------------------------------------------- Logs

  Future<Paginado<LogEntry>> listarLogs({
    String? nivel,
    String? busca,
    String? usuario,
    int pagina = 1,
    int porPagina = 50,
  }) async {
    final body = await _send('GET', '/logs', query: {
      'nivel': nivel,
      'busca': busca,
      'usuario': usuario,
      'pagina': '$pagina',
      'por_pagina': '$porPagina',
    });
    return Paginado.fromJson(body, LogEntry.fromJson);
  }

  Future<LogEntry> buscarLog(int id) async =>
      LogEntry.fromJson((await _send('GET', '/logs/$id'))['data'] as Map<String, dynamic>);

  /// Remove logs com mais de [dias] dias. Devolve quantos foram removidos.
  Future<int> limparLogs(int dias) async {
    final d = (await _send('DELETE', '/logs', query: {'dias': '$dias'}))['data'] as Map<String, dynamic>;
    return (d['removidos'] as num).toInt();
  }

  // ------------------------------------------------------------ Infra

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
    bool autenticado = true,
  }) async {
    final params = <String, String>{
      for (final e in (query ?? const <String, String?>{}).entries)
        if (e.value != null && e.value!.trim().isNotEmpty) e.key: e.value!.trim(),
    };
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);

    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (autenticado && token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ApiException(0, 'Tempo esgotado ao acessar $baseUrl.');
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Não foi possível conectar a $baseUrl (${e.message}).');
    }

    if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
      if (response.statusCode >= 400) throw ApiException(response.statusCode, 'Erro HTTP ${response.statusCode}.');
      return const {};
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(response.statusCode,
          'Resposta inválida do servidor (HTTP ${response.statusCode}). Verifique a URL da API.');
    }

    if (response.statusCode >= 400 || json.containsKey('error')) {
      final err = (json['error'] as Map?)?.cast<String, dynamic>() ?? const {};
      final details = (err['details'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {};
      throw ApiException(
        (err['status'] as num?)?.toInt() ?? response.statusCode,
        err['message'] as String? ?? 'Erro HTTP ${response.statusCode}.',
        details,
      );
    }
    return json;
  }
}
