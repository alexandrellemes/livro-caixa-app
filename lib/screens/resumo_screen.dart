import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/movimento.dart';
import '../models/resumo.dart';
import '../session.dart';
import '../util/format.dart' as fmt;
import '../widgets/comum.dart';
import '../widgets/recarrega.dart';

/// GET /resumo + últimos lançamentos do mês.
class ResumoScreen extends StatefulWidget {
  const ResumoScreen({super.key});

  @override
  State<ResumoScreen> createState() => _ResumoScreenState();
}

class _ResumoScreenState extends State<ResumoScreen> with RecarregaAoAlterar {
  int _mes = DateTime.now().month;
  int _ano = DateTime.now().year;
  late Future<(Resumo, List<Movimento>)> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  Future<(Resumo, List<Movimento>)> _carregar() async {
    final api = context.read<Session>().api;
    // As duas requisições rodam em paralelo.
    final resumo = api.resumo(mes: _mes, ano: _ano);
    final ultimos = api.listarMovimentos(mes: _mes, ano: _ano, porPagina: 5);
    try {
      return (await resumo, (await ultimos).itens);
    } catch (_) {
      ultimos.ignore(); // evita erro não tratado se a primeira falhar
      rethrow;
    }
  }

  @override
  void recarregar() => setState(() => _futuro = _carregar());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SeletorMes(
          mes: _mes,
          ano: _ano,
          onChanged: (m, a) {
            _mes = m;
            _ano = a;
            recarregar();
          },
        ),
        Expanded(
          child: FutureBuilder(
            future: _futuro,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErroView(mensagem: tratarErro(context, snap.error!), onTentarNovamente: recarregar);
              }
              final (resumo, ultimos) = snap.data!;
              return RefreshIndicator(
                onRefresh: () async {
                  recarregar();
                  await _futuro;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _CartaoTotais(titulo: 'Mês', totais: resumo.mensal, destaque: true),
                    const SizedBox(height: 12),
                    _CartaoTotais(titulo: 'Geral (todos os meses)', totais: resumo.geral),
                    const SizedBox(height: 24),
                    Text('Últimos lançamentos do mês', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (ultimos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Nenhum lançamento neste mês.'),
                      ),
                    for (final m in ultimos)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          m.isReceita ? Icons.arrow_downward : Icons.arrow_upward,
                          color: corTipo(context, receita: m.isReceita),
                        ),
                        title: Text(m.descricao, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${fmt.data(m.data)} · ${m.categoriaNome ?? 'Sem categoria'}'),
                        trailing: Text(
                          '${m.isReceita ? '+' : '−'} ${fmt.moeda(m.valor)}',
                          style: TextStyle(
                              color: corTipo(context, receita: m.isReceita),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CartaoTotais extends StatelessWidget {
  const _CartaoTotais({required this.titulo, required this.totais, this.destaque = false});

  final String titulo;
  final Totais totais;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final positivo = totais.resultado >= 0;

    Widget linha(String rotulo, double valor, Color cor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(rotulo)),
              Text(fmt.moeda(valor), style: tt.bodyLarge?.copyWith(color: cor)),
            ],
          ),
        );

    return Card(
      color: destaque ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: tt.labelLarge),
            const SizedBox(height: 4),
            Text(
              fmt.moeda(totais.resultado),
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: corTipo(context, receita: positivo),
              ),
            ),
            Text('Resultado', style: tt.bodySmall),
            const Divider(height: 24),
            linha('Entradas', totais.entradas, corTipo(context, receita: true)),
            linha('Saídas', totais.saidas, corTipo(context, receita: false)),
          ],
        ),
      ),
    );
  }
}
