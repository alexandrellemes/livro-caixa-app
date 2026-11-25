/// Item de GET /auth/tokens (sem o valor do token).
class TokenInfo {
  const TokenInfo({
    required this.id,
    required this.nome,
    this.criadoEm,
    this.expiraEm,
    this.ultimoUso,
    this.revogadoEm,
  });

  final int id;
  final String nome;
  final DateTime? criadoEm;
  final DateTime? expiraEm;
  final DateTime? ultimoUso;
  final DateTime? revogadoEm;

  bool get ativo =>
      revogadoEm == null && (expiraEm == null || expiraEm!.isAfter(DateTime.now()));

  static DateTime? _data(Object? v) => v is String ? DateTime.tryParse(v) : null;

  factory TokenInfo.fromJson(Map<String, dynamic> j) => TokenInfo(
        id: (j['id'] as num).toInt(),
        nome: j['nome'] as String? ?? '',
        criadoEm: _data(j['criado_em']),
        expiraEm: _data(j['expira_em']),
        ultimoUso: _data(j['ultimo_uso']),
        revogadoEm: _data(j['revogado_em']),
      );
}
