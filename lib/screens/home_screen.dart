import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../session.dart';
import 'categorias_screen.dart';
import 'conta_screen.dart';
import 'logs_screen.dart';
import 'movimentos_screen.dart';
import 'resumo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    final abas = <({String titulo, IconData icone, IconData iconeAtivo, Widget tela})>[
      (titulo: 'Resumo', icone: Icons.insights_outlined, iconeAtivo: Icons.insights, tela: const ResumoScreen()),
      (
        titulo: 'Movimentos',
        icone: Icons.receipt_long_outlined,
        iconeAtivo: Icons.receipt_long,
        tela: const MovimentosScreen()
      ),
      (titulo: 'Categorias', icone: Icons.label_outline, iconeAtivo: Icons.label, tela: const CategoriasScreen()),
      if (session.isAdmin)
        (titulo: 'Logs', icone: Icons.history_outlined, iconeAtivo: Icons.history, tela: const LogsScreen()),
    ];
    final indice = _indice.clamp(0, abas.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(abas[indice].titulo),
        actions: [
          IconButton(
            tooltip: 'Conta',
            icon: CircleAvatar(
              radius: 15,
              child: Text((session.usuario ?? '?').substring(0, 1).toUpperCase()),
            ),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ContaScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: indice, children: [for (final a in abas) a.tela]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: [
          for (final a in abas)
            NavigationDestination(icon: Icon(a.icone), selectedIcon: Icon(a.iconeAtivo), label: a.titulo),
        ],
      ),
    );
  }
}
