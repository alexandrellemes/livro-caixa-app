/// Lista paginada: {"data": [...], "meta": {"total", "pagina", "por_pagina", "paginas"}}.
class Paginado<T> {
  const Paginado({
    required this.itens,
    required this.total,
    required this.pagina,
    required this.porPagina,
    required this.paginas,
  });

  final List<T> itens;
  final int total;
  final int pagina;
  final int porPagina;
  final int paginas;

  bool get temMais => pagina < paginas;

  factory Paginado.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final itens = (json['data'] as List).map((e) => item(e as Map<String, dynamic>)).toList();
    return Paginado(
      itens: itens,
      total: (meta['total'] as num?)?.toInt() ?? itens.length,
      pagina: (meta['pagina'] as num?)?.toInt() ?? 1,
      porPagina: (meta['por_pagina'] as num?)?.toInt() ?? itens.length,
      paginas: (meta['paginas'] as num?)?.toInt() ?? 1,
    );
  }
}
