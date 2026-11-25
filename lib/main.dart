import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(
    ChangeNotifierProvider(
      create: (_) => Session()..carregar(),
      child: const LivroCaixaApp(),
    ),
  );
}

class LivroCaixaApp extends StatelessWidget {
  const LivroCaixaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1B6E4F);
    return MaterialApp(
      title: 'Livro Caixa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Consumer<Session>(
        builder: (context, session, _) {
          if (session.carregando) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return session.logado ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
