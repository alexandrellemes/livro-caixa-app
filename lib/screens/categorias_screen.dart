import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/categoria.dart';
import '../session.dart';
import '../widgets/comum.dart';
import '../widgets/recarrega.dart';

/// GET/POST/PUT/DELETE /categorias.
class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> with RecarregaAoAlterar {
  late Future<List<Categoria>> _futuro;
  String _busca = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<Categoria>> _carregar() => context.read<Session>().api.listarCategorias(busca: _busca);

  @override
  void recarregar() => setState(() => _futuro = _carregar());

  Future<void> _editar([Categoria? c]) async {
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => _NomeDialog(inicial: c?.nome),
    );
    if (nome == null || !mounted) return;

    final session = context.read<Session>();
    try {
      if (c == null) {
        await session.api.criarCategoria(nome);
      } else {
        await session.api.atualizarCategoria(c.id, nome);
      }
      if (!mounted) return;
      mostrarMensagem(context, c == null ? 'Categoria criada.' : 'Categoria atualizada.');
      session.dadosAlterados();
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  Future<void> _remover(Categoria c) async {
    if (!await confirmar(context, 'Remover categoria', 'Remover a categoria "${c.nome}"?')) return;
    if (!mounted) return;
    final session = context.read<Session>();
    try {
      await session.api.removerCategoria(c.id);
      if (!mounted) return;
      mostrarMensagem(context, 'Categoria removida.');
      session.dadosAlterados();
    } catch (e) {
      // 409 quando a categoria tem movimentos: a mensagem da API explica.
      if (mounted) mostrarErro(context, e);
    }
  }

  Future<void> _detalhes(Categoria c) async {
    try {
      final det = await context.read<Session>().api.buscarCategoria(c.id);
      if (!mounted) return;
      mostrarMensagem(context, '${det.nome}: ${det.totalMovimentos ?? 0} movimento(s).');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.select<Session, bool>((s) => s.isAdmin);

    return Scaffold(
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _editar(),
              icon: const Icon(Icons.add),
              label: const Text('Categoria'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Buscar categoria',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  _busca = v.trim();
                  recarregar();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Categoria>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErroView(mensagem: tratarErro(context, snap.error!), onTentarNovamente: recarregar);
                }
                final lista = snap.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    recarregar();
                    await _futuro;
                  },
                  child: lista.isEmpty
                      ? const VazioView(mensagem: 'Nenhuma categoria.', icone: Icons.label_off_outlined)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: lista.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final c = lista[i];
                            return ListTile(
                              leading: const Icon(Icons.label_outline),
                              title: Text(c.nome),
                              subtitle: Text('#${c.id}'),
                              onTap: () => _detalhes(c),
                              trailing: admin
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _editar(c),
                                        ),
                                        IconButton(
                                          tooltip: 'Remover',
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () => _remover(c),
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NomeDialog extends StatefulWidget {
  const _NomeDialog({this.inicial});

  final String? inicial;

  @override
  State<_NomeDialog> createState() => _NomeDialogState();
}

class _NomeDialogState extends State<_NomeDialog> {
  late final _ctrl = TextEditingController(text: widget.inicial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ok() {
    if (_form.currentState!.validate()) Navigator.pop(context, _ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.inicial == null ? 'Nova categoria' : 'Editar categoria'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome'),
          onFieldSubmitted: (_) => _ok(),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome.' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _ok, child: const Text('Salvar')),
      ],
    );
  }
}
