class Totais {
  const Totais({required this.entradas, required this.saidas, required this.resultado});

  final double entradas;
  final double saidas;
  final double resultado;

  factory Totais.fromJson(Map<String, dynamic> j) => Totais(
        entradas: (j['entradas'] as num? ?? 0).toDouble(),
        saidas: (j['saidas'] as num? ?? 0).toDouble(),
        resultado: (j['resultado'] as num? ?? 0).toDouble(),
      );
}

/// GET /resumo?mes=&ano=
class Resumo {
  const Resumo({required this.mes, required this.ano, required this.mensal, required this.geral});

  final int mes;
  final int ano;
  final Totais mensal;
  final Totais geral;

  factory Resumo.fromJson(Map<String, dynamic> j) => Resumo(
        mes: (j['mes'] as num).toInt(),
        ano: (j['ano'] as num).toInt(),
        mensal: Totais.fromJson((j['mensal'] as Map).cast<String, dynamic>()),
        geral: Totais.fromJson((j['geral'] as Map).cast<String, dynamic>()),
      );
}
