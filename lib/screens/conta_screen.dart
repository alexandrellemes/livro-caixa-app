import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/token_info.dart';
import '../session.dart';
import '../util/format.dart' as fmt;
import '../widgets/comum.dart';

/// Usuário logado, tokens de API (GET /auth/tokens, DELETE /auth/tokens/{id}) e sair.
class ContaScreen extends StatefulWidget {
  const ContaScreen({super.key});

  @override
  State<ContaScreen> createState() => _ContaScreenState();
}

class _ContaScreenState extends State<ContaScreen> {
  late Future<List<TokenInfo>> _tokens = context.read<Session>().api.listarTokens();

  void _recarregar() => setState(() => _tokens = context.read<Session>().api.listarTokens());

  Future<void> _revogar(TokenInfo t) async {
    if (!await confirmar(context, 'Revogar token', 'Revogar o token "${t.nome}" (#${t.id})?',
        acao: 'Revogar')) {
      return;
    }
    if (!mounted) return;
    try {
      await context.read<Session>().api.revogarToken(t.id);
      if (!mounted) return;
      mostrarMensagem(context, 'Token revogado.');
      _recarregar();
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  Future<void> _sair() async {
    if (!await confirmar(context, 'Sair', 'Encerrar a sessão neste dispositivo?', acao: 'Sair')) return;
    if (!mounted) return;
    final session = context.read<Session>();
    Navigator.popUntil(context, (r) => r.isFirst);
    await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.logado) return const SizedBox.shrink();
    final tokenAtual = session.api.token;

    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(session.usuario ?? '—'),
            subtitle: Text('Perfil: ${session.perfil ?? '—'}'
                '${session.isAdmin ? ' (consulta e altera)' : ' (somente consulta)'}'),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Servidor'),
            subtitle: Text(session.baseUrl),
          ),
          const Divider(),
          ListTile(
            title: Text('Tokens de API', style: Theme.of(context).textTheme.titleSmall),
            trailing: IconButton(
                tooltip: 'Atualizar', onPressed: _recarregar, icon: const Icon(Icons.refresh)),
          ),
          FutureBuilder<List<TokenInfo>>(
            future: _tokens,
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tratarErro(context, snap.error!)),
                );
              }
              final lista = snap.data;
              if (lista == null) return const LinearProgressIndicator();
              if (lista.isEmpty) {
                return const ListTile(title: Text('Nenhum token.'));
              }
              return Column(
                children: [
                  for (final t in lista)
                    ListTile(
                      leading: Icon(t.ativo ? Icons.key : Icons.key_off,
                          color: t.ativo ? null : Theme.of(context).colorScheme.outline),
                      title: Text('${t.nome} #${t.id}'),
                      subtitle: Text(t.revogadoEm != null
                          ? 'Revogado em ${fmt.dataHora(t.revogadoEm)}'
                          : 'Expira em ${fmt.dataHora(t.expiraEm)}'
                              ' · último uso ${fmt.dataHora(t.ultimoUso)}'),
                      trailing: t.ativo
                          ? IconButton(
                              tooltip: 'Revogar',
                              icon: const Icon(Icons.block),
                              onPressed: () => _revogar(t),
                            )
                          : null,
                    ),
                ],
              );
            },
          ),
          if (tokenAtual != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Revogar o token desta sessão desconecta o app. Use "Sair" para isso.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _sair,
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
            ),
          ),
        ],
      ),
    );
  }
}
