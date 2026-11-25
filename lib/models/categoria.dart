class Categoria {
  const Categoria({required this.id, required this.nome, this.totalMovimentos});

  final int id;
  final String nome;

  /// Só vem em GET /categorias/{id}.
  final int? totalMovimentos;

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
        id: (j['id'] as num).toInt(),
        nome: j['nome'] as String? ?? '',
        totalMovimentos: (j['total_movimentos'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) => other is Categoria && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
