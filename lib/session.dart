import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';

/// Estado de login: URL da API, token e perfil, persistidos no dispositivo.
class Session extends ChangeNotifier {
  static const _kBaseUrl = 'base_url';
  static const _kToken = 'token';
  static const _kUsuario = 'usuario';
  static const _kPerfil = 'perfil';

  /// No emulador Android, "localhost" do PC é 10.0.2.2.
  static String get urlPadrao => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';

  String baseUrl = urlPadrao;
  String? usuario;
  String? perfil;
  ApiClient? _api;
  bool carregando = true;

  /// Incrementado a cada alteração (movimento/categoria) para as outras abas recarregarem.
  int versaoDados = 0;

  void dadosAlterados() {
    versaoDados++;
    notifyListeners();
  }

  bool get logado => _api?.token != null;
  bool get isAdmin => perfil == 'admin';

  ApiClient get api => _api ?? (throw StateError('Sessão não iniciada.'));

  /// Restaura a sessão salva e valida o token em GET /auth/me.
  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_kBaseUrl) ?? urlPadrao;
    final token = prefs.getString(_kToken);
    usuario = prefs.getString(_kUsuario);
    perfil = prefs.getString(_kPerfil);

    if (token != null) {
      _api = ApiClient(baseUrl: baseUrl, token: token);
      try {
        final me = await _api!.me();
        usuario = me.usuario;
        perfil = me.perfil;
        await prefs.setString(_kPerfil, me.perfil);
      } on ApiException catch (e) {
        // Token expirado/revogado: volta ao login. Sem rede: mantém a sessão salva.
        if (e.naoAutorizado) await _limpar(prefs);
      }
    }
    carregando = false;
    notifyListeners();
  }

  Future<void> login(String url, String username, String password) async {
    final client = ApiClient(baseUrl: url);
    final gerado = await client.gerarToken(username, password);
    client.token = gerado.token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, client.baseUrl);
    await prefs.setString(_kToken, gerado.token);
    await prefs.setString(_kUsuario, gerado.usuario);
    await prefs.setString(_kPerfil, gerado.perfil);

    baseUrl = client.baseUrl;
    usuario = gerado.usuario;
    perfil = gerado.perfil;
    _api = client;
    notifyListeners();
  }

  /// Revoga o token no servidor (se possível) e limpa a sessão local.
  Future<void> logout({bool revogar = true}) async {
    if (revogar && _api != null) {
      try {
        await _api!.revogarTokenAtual();
      } catch (_) {
        // Ignora: o token local é descartado de qualquer forma.
      }
    }
    await _limpar(await SharedPreferences.getInstance());
    notifyListeners();
  }

  Future<void> _limpar(SharedPreferences prefs) async {
    await prefs.remove(_kToken);
    await prefs.remove(_kUsuario);
    await prefs.remove(_kPerfil);
    _api = null;
    usuario = null;
    perfil = null;
  }
}
