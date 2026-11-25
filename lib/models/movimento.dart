enum TipoMovimento {
  receita('receita', 'Receita'),
  despesa('despesa', 'Despesa');

  const TipoMovimento(this.api, this.rotulo);

  final String api;
  final String rotulo;

  static TipoMovimento fromApi(Object? v) => v == 'receita' || v == 1 ? receita : despesa;
}

class Movimento {
  const Movimento({
    this.id,
    required this.data,
    required this.tipo,
    required this.descricao,
    required this.valor,
    required this.categoriaId,
    this.categoriaNome,
  });

  final int? id;
  final DateTime data;
  final TipoMovimento tipo;
  final String descricao;
  final double valor;
  final int? categoriaId;
  final String? categoriaNome;

  bool get isReceita => tipo == TipoMovimento.receita;

  factory Movimento.fromJson(Map<String, dynamic> j) {
    final cat = (j['categoria'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Movimento(
      id: (j['id'] as num?)?.toInt(),
      data: DateTime.parse(j['data'] as String),
      tipo: TipoMovimento.fromApi(j['tipo']),
      descricao: j['descricao'] as String? ?? '',
      valor: (j['valor'] as num).toDouble(),
      categoriaId: (cat['id'] as num?)?.toInt(),
      categoriaNome: cat['nome'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'data': '${data.year.toString().padLeft(4, '0')}-'
            '${data.month.toString().padLeft(2, '0')}-'
            '${data.day.toString().padLeft(2, '0')}',
        'tipo': tipo.api,
        'descricao': descricao,
        'valor': double.parse(valor.toStringAsFixed(2)),
        'categoria_id': categoriaId,
      };
}
