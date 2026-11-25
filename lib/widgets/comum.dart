import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../session.dart';
import '../util/format.dart' as fmt;

/// Texto do erro; se o token deixou de valer (401), encerra a sessão.
String tratarErro(BuildContext context, Object erro) {
  if (erro is ApiException) {
    if (erro.naoAutorizado) {
      context.read<Session>().logout(revogar: false);
    }
    return erro.descricao;
  }
  return erro.toString();
}

void mostrarErro(BuildContext context, Object erro) {
  final msg = tratarErro(context, erro);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
}

void mostrarMensagem(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirmar(BuildContext context, String titulo, String mensagem,
    {String acao = 'Remover'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(acao)),
      ],
    ),
  );
  return ok ?? false;
}

class ErroView extends StatelessWidget {
  const ErroView({super.key, required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onTentarNovamente,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class VazioView extends StatelessWidget {
  const VazioView({super.key, required this.mensagem, this.icone = Icons.inbox_outlined});

  final String mensagem;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    // ListView para que o RefreshIndicator funcione com a lista vazia.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icone, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(mensagem, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Barra "‹ Novembro 2026 ›" para navegar entre meses.
class SeletorMes extends StatelessWidget {
  const SeletorMes({super.key, required this.mes, required this.ano, required this.onChanged});

  final int mes;
  final int ano;
  final void Function(int mes, int ano) onChanged;

  void _mover(int delta) {
    final d = DateTime(ano, mes + delta);
    onChanged(d.month, d.year);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            tooltip: 'Mês anterior', onPressed: () => _mover(-1), icon: const Icon(Icons.chevron_left)),
        TextButton(
          onPressed: () {
            final hoje = DateTime.now();
            onChanged(hoje.month, hoje.year);
          },
          child: Text(fmt.mesAno(mes, ano), style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
            tooltip: 'Próximo mês', onPressed: () => _mover(1), icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

/// Cores de receita/despesa que funcionam no tema claro e escuro.
Color corTipo(BuildContext context, {required bool receita}) {
  final escuro = Theme.of(context).brightness == Brightness.dark;
  if (receita) return escuro ? const Color(0xFF6FD39B) : const Color(0xFF17803D);
  return escuro ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
}
