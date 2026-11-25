import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/log_entry.dart';
import '../session.dart';
import '../util/format.dart' as fmt;
import '../widgets/comum.dart';

const _niveis = ['debug', 'info', 'warning', 'error', 'critical'];

/// GET /logs, GET /logs/{id} e DELETE /logs?dias= (somente admin).
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  static const _porPagina = 50;

  String? _nivel;
  String _busca = '';
  final _itens = <LogEntry>[];
  final _scroll = ScrollController();
  int _pagina = 0;
  int _total = 0;
  bool _temMais = true;
  bool _carregando = false;
  String? _erro;
  int _geracao = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _proximaPagina();
    });
    _recarregar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _recarregar() {
    _geracao++;
    setState(() {
      _itens.clear();
      _pagina = 0;
      _total = 0;
      _temMais = true;
      _carregando = false;
      _erro = null;
    });
    _proximaPagina();
  }

  Future<void> _proximaPagina() async {
    if (_carregando || !_temMais) return;
    final geracao = _geracao;
    setState(() => _carregando = true);
    try {
      final p = await context.read<Session>().api.listarLogs(
            nivel: _nivel,
            busca: _busca,
            pagina: _pagina + 1,
            porPagina: _porPagina,
          );
      if (!mounted || geracao != _geracao) return;
      setState(() {
        _itens.addAll(p.itens);
        _pagina = p.pagina;
        _total = p.total;
        _temMais = p.temMais;
      });
    } catch (e) {
      if (!mounted || geracao != _geracao) return;
      setState(() => _erro = tratarErro(context, e));
    } finally {
      if (mounted && geracao == _geracao) setState(() => _carregando = false);
    }
  }

  Future<void> _limpar() async {
    final dias = await showDialog<int>(context: context, builder: (_) => const _LimparDialog());
    if (dias == null || !mounted) return;
    try {
      final removidos = await context.read<Session>().api.limparLogs(dias);
      if (!mounted) return;
      mostrarMensagem(context, '$removidos registro(s) removido(s).');
      _recarregar();
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Buscar (Enter)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) {
                    _busca = v.trim();
                    _recarregar();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Limpar logs antigos',
                onPressed: _limpar,
                icon: const Icon(Icons.cleaning_services_outlined),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final n in _niveis) ...[
                ChoiceChip(
                  label: Text(n),
                  selected: _nivel == n,
                  onSelected: (v) {
                    _nivel = v ? n : null;
                    _recarregar();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('$_total registro(s)', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        Expanded(child: _lista()),
      ],
    );
  }

  Widget _lista() {
    if (_erro != null && _itens.isEmpty) return ErroView(mensagem: _erro!, onTentarNovamente: _recarregar);
    if (_itens.isEmpty && _carregando) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () async => _recarregar(),
      child: _itens.isEmpty
          ? const VazioView(mensagem: 'Nenhum registro.')
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _itens.length + (_temMais ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == _itens.length) {
                  return _erro != null
                      ? TextButton(onPressed: _proximaPagina, child: const Text('Erro. Tentar de novo'))
                      : const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                }
                final l = _itens[i];
                return ListTile(
                  leading: _IconeNivel(l.nivel),
                  title: Text(l.mensagem, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${fmt.dataHora(l.dataHora)} · ${l.acao} · ${l.usuario ?? '—'}'),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => LogDetalheScreen(id: l.id))),
                );
              },
            ),
    );
  }
}

class _IconeNivel extends StatelessWidget {
  const _IconeNivel(this.nivel);

  final String nivel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icone, cor) = switch (nivel) {
      'critical' || 'error' => (Icons.error_outline, cs.error),
      'warning' => (Icons.warning_amber, Colors.orange),
      'debug' => (Icons.bug_report_outlined, cs.outline),
      _ => (Icons.info_outline, cs.primary),
    };
    return Icon(icone, color: cor);
  }
}

class _LimparDialog extends StatefulWidget {
  const _LimparDialog();

  @override
  State<_LimparDialog> createState() => _LimparDialogState();
}

class _LimparDialogState extends State<_LimparDialog> {
  final _ctrl = TextEditingController(text: '90');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dias = int.tryParse(_ctrl.text);
    return AlertDialog(
      title: const Text('Limpar logs antigos'),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Remover registros com mais de (dias)'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: dias != null && dias >= 1 ? () => Navigator.pop(context, dias) : null,
          child: const Text('Remover'),
        ),
      ],
    );
  }
}

class LogDetalheScreen extends StatelessWidget {
  const LogDetalheScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Log #$id')),
      body: FutureBuilder<LogEntry>(
        future: context.read<Session>().api.buscarLog(id),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(tratarErro(context, snap.error!)));
          }
          final l = snap.data;
          if (l == null) return const Center(child: CircularProgressIndicator());

          final mono = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
          Widget campo(String rotulo, String? valor) => ListTile(
                dense: true,
                title: Text(rotulo),
                subtitle: SelectableText(valor == null || valor.isEmpty ? '—' : valor),
              );

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ListTile(
                leading: _IconeNivel(l.nivel),
                title: Text(l.mensagem),
                subtitle: Text(fmt.dataHora(l.dataHora)),
              ),
              const Divider(),
              campo('Nível', l.nivel),
              campo('Ação', l.acao),
              campo('Usuário', l.usuario),
              campo('IP', l.ip),
              campo('Entidade', l.entidade == null ? null : '${l.entidade} #${l.entidadeId ?? ''}'),
              if (l.requisicao != null) ...[
                campo('Requisição', '${l.requisicao!['metodo'] ?? ''} ${l.requisicao!['uri'] ?? ''}'),
                campo('User agent', l.requisicao!['user_agent'] as String?),
              ],
              if (l.contexto != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contexto', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ').convert(l.contexto),
                          style: mono,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
