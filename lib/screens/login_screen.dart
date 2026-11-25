import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final _url = TextEditingController(
      text: context.read<Session>().baseUrl.replaceFirst(RegExp(r'/api/v1$'), ''));
  final _usuario = TextEditingController();
  final _senha = TextEditingController();
  bool _enviando = false;
  bool _verSenha = false;
  String? _erro;

  @override
  void dispose() {
    _url.dispose();
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await context.read<Session>().login(_url.text, _usuario.text.trim(), _senha.text);
    } on ApiException catch (e) {
      setState(() => _erro = e.descricao);
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String? obrigatorio(String? v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.account_balance_wallet, size: 64, color: cs.primary),
                    const SizedBox(height: 8),
                    Text('Livro Caixa',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Servidor',
                        hintText: 'http://localhost:8080',
                        prefixIcon: Icon(Icons.dns_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: obrigatorio,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usuario,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Usuário',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: obrigatorio,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senha,
                      obscureText: !_verSenha,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _verSenha ? 'Ocultar senha' : 'Mostrar senha',
                          icon: Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _verSenha = !_verSenha),
                        ),
                      ),
                      validator: obrigatorio,
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 16),
                      Text(_erro!, style: TextStyle(color: cs.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _enviando ? null : _entrar,
                      icon: _enviando
                          ? const SizedBox.square(
                              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
