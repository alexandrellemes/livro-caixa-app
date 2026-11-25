import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/categoria.dart';
import '../models/movimento.dart';
import '../session.dart';
import '../util/format.dart' as fmt;
import '../widgets/comum.dart';
import '../widgets/recarrega.dart';
import 'movimento_form_screen.dart';

/// GET /movimentos com filtros de mês, tipo, categoria e busca, carregando por páginas.
class MovimentosScreen extends StatefulWidget {
  const MovimentosScreen({super.key});

  @override
  State<MovimentosScreen> createState() => _MovimentosScreenState();
}

class _MovimentosScreenState extends State<MovimentosScreen> with RecarregaAoAlterar {
  static const _porPagina = 30;

  int _mes = DateTime.now().month;
  int _ano = DateTime.now().year;
  bool _todosOsMeses = false;
  TipoMovimento? _tipo;
  Categoria? _categoria;
  String _busca = '';

  final _itens = <Movimento>[];
  final _scroll = ScrollController();
  final _buscaCtrl = TextEditingController();
  Timer? _debounce;
  int _pagina = 0;
  int _total = 0;
  bool _temMais = true;
  bool _carregando = false;
  String? _erro;
  int _geracao = 0; // descarta respostas de filtros antigos

  List<Categoria> _categorias = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _proximaPagina();
    });
    recarregar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _buscaCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void recarregar() {
    _geracao++;
    setState(() {
      _itens.clear();
      _pagina = 0;
      _total = 0;
      _temMais = true;
      _carregando = false;
      _erro = null;
    });
    _carregarCategorias();
    _proximaPagina();
  }

  Future<void> _carregarCategorias() async {
    try {
      final lista = await context.read<Session>().api.listarCategorias();
      if (mounted) setState(() => _categorias = lista);
    } catch (_) {
      // O filtro por categoria só fica indisponível.
    }
  }

  Future<void> _proximaPagina() async {
    if (_carregando || !_temMais) return;
    final geracao = _geracao;
    setState(() => _carregando = true);
    try {
      final pagina = await context.read<Session>().api.listarMovimentos(
            mes: _todosOsMeses ? null : _mes,
            ano: _todosOsMeses ? null : _ano,
            tipo: _tipo,
            categoriaId: _categoria?.id,
            busca: _busca,
            pagina: _pagina + 1,
            porPagina: _porPagina,
          );
      if (!mounted || geracao != _geracao) return;
      setState(() {
        _itens.addAll(pagina.itens);
        _pagina = pagina.pagina;
        _total = pagina.total;
        _temMais = pagina.temMais;
      });
    } catch (e) {
      if (!mounted || geracao != _geracao) return;
      setState(() => _erro = tratarErro(context, e));
    } finally {
      if (mounted && geracao == _geracao) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirFormulario([Movimento? m]) async {
    final salvo = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MovimentoFormScreen(movimento: m)),
    );
    if (salvo == true && mounted) context.read<Session>().dadosAlterados();
  }

  Future<bool> _remover(Movimento m) async {
    if (!await confirmar(context, 'Remover movimento', 'Remover "${m.descricao}" (${fmt.moeda(m.valor)})?')) {
      return false;
    }
    if (!mounted) return false;
    final session = context.read<Session>();
    try {
      await session.api.removerMovimento(m.id!);
      if (!mounted) return true;
      mostrarMensagem(context, 'Movimento removido.');
      session.dadosAlterados();
      return true;
    } catch (e) {
      if (mounted) mostrarErro(context, e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.select<Session, bool>((s) => s.isAdmin);

    return Scaffold(
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Lançar'),
            )
          : null,
      body: Column(
        children: [
          if (_todosOsMeses)
            const SizedBox(height: 8)
          else
            SeletorMes(
              mes: _mes,
              ano: _ano,
              onChanged: (m, a) {
                _mes = m;
                _ano = a;
                recarregar();
              },
            ),
          _filtros(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('$_total lançamento(s)', style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          Expanded(child: _lista(admin)),
        ],
      ),
    );
  }

  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _buscaCtrl,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar na descrição',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _busca.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _buscaCtrl.clear();
                        _busca = '';
                        recarregar();
                      },
                    ),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                _busca = v.trim();
                recarregar();
              });
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos os meses'),
                  selected: _todosOsMeses,
                  onSelected: (v) {
                    _todosOsMeses = v;
                    recarregar();
                  },
                ),
                const SizedBox(width: 8),
                for (final t in TipoMovimento.values) ...[
                  FilterChip(
                    label: Text(t == TipoMovimento.receita ? 'Receitas' : 'Despesas'),
                    selected: _tipo == t,
                    onSelected: (v) {
                      _tipo = v ? t : null;
                      recarregar();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                PopupMenuButton<Categoria>(
                  tooltip: 'Filtrar por categoria',
                  onSelected: (c) {
                    _categoria = c.id == 0 ? null : c;
                    recarregar();
                  },
                  itemBuilder: (_) => [
                    // id 0 = sem filtro (um valor null não chega ao onSelected).
                    const PopupMenuItem(
                        value: Categoria(id: 0, nome: ''), child: Text('Todas as categorias')),
                    for (final c in _categorias) PopupMenuItem(value: c, child: Text(c.nome)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.label_outline, size: 18),
                    label: Text(_categoria?.nome ?? 'Categoria'),
                    backgroundColor:
                        _categoria != null ? Theme.of(context).colorScheme.secondaryContainer : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(bool admin) {
    if (_erro != null && _itens.isEmpty) {
      return ErroView(mensagem: _erro!, onTentarNovamente: recarregar);
    }
    if (_itens.isEmpty && _carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async => recarregar(),
      child: _itens.isEmpty
          ? const VazioView(mensagem: 'Nenhum lançamento encontrado.')
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _itens.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == _itens.length) {
                  if (_erro != null) {
                    return TextButton(onPressed: _proximaPagina, child: const Text('Erro. Tentar de novo'));
                  }
                  return _temMais
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : const SizedBox(height: 8);
                }
                return _item(_itens[i], admin);
              },
            ),
    );
  }

  Widget _item(Movimento m, bool admin) {
    final cor = corTipo(context, receita: m.isReceita);
    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: cor.withValues(alpha: 0.15),
        child: Icon(m.isReceita ? Icons.arrow_downward : Icons.arrow_upward, color: cor),
      ),
      title: Text(m.descricao, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${fmt.data(m.data)} · ${m.categoriaNome ?? 'Sem categoria'}'),
      trailing: Text(
        '${m.isReceita ? '+' : '−'} ${fmt.moeda(m.valor)}',
        style: TextStyle(color: cor, fontWeight: FontWeight.w600),
      ),
      onTap: () => admin ? _abrirFormulario(m) : _detalhes(m),
    );

    if (!admin) return tile;
    return Dismissible(
      key: ValueKey(m.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      // A remoção recarrega a lista; o Dismissible em si não some sozinho.
      confirmDismiss: (_) async {
        await _remover(m);
        return false;
      },
      child: tile,
    );
  }

  void _detalhes(Movimento m) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.descricao, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(fmt.moeda(m.valor),
                style: Theme.of(ctx)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: corTipo(ctx, receita: m.isReceita))),
            const SizedBox(height: 16),
            Text('Tipo: ${m.tipo.rotulo}'),
            Text('Data: ${fmt.data(m.data)}'),
            Text('Categoria: ${m.categoriaNome ?? '—'}'),
            Text('Id: ${m.id}'),
          ],
        ),
      ),
    );
  }
}
