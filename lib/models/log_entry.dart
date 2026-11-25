class LogEntry {
  const LogEntry({
    required this.id,
    required this.dataHora,
    required this.nivel,
    required this.acao,
    required this.mensagem,
    this.entidade,
    this.entidadeId,
    this.usuario,
    this.ip,
    this.contexto,
    this.requisicao,
  });

  final int id;
  final DateTime? dataHora;
  final String nivel;
  final String acao;
  final String mensagem;
  final String? entidade;
  final String? entidadeId;
  final String? usuario;
  final String? ip;

  /// Só vêm em GET /logs/{id}.
  final Object? contexto;
  final Map<String, dynamic>? requisicao;

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: (j['id'] as num).toInt(),
        dataHora: DateTime.tryParse(j['data_hora'] as String? ?? '')?.toLocal(),
        nivel: j['nivel'] as String? ?? '',
        acao: j['acao'] as String? ?? '',
        mensagem: j['mensagem'] as String? ?? '',
        entidade: j['entidade'] as String?,
        entidadeId: j['entidade_id']?.toString(),
        usuario: j['usuario'] as String?,
        ip: j['ip'] as String?,
        contexto: j['contexto'],
        requisicao: (j['requisicao'] as Map?)?.cast<String, dynamic>(),
      );
}
