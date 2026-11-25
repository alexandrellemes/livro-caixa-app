import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/categoria.dart';
import '../models/movimento.dart';
import '../session.dart';
import '../util/format.dart' as fmt;
import '../widgets/comum.dart';

/// POST /movimentos (novo) ou PUT /movimentos/{id} (edição). Retorna `true` se salvou.
class MovimentoFormScreen extends StatefulWidget {
  const MovimentoFormScreen({super.key, this.movimento});

  final Movimento? movimento;

  @override
  State<MovimentoFormScreen> createState() => _MovimentoFormScreenState();
}

class _MovimentoFormScreenState extends State<MovimentoFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _descricao = TextEditingController(text: widget.movimento?.descricao);
  late final _valor = TextEditingController(
      text: widget.movimento == null ? '' : fmt.valorEditavel(widget.movimento!.valor));
  late DateTime _data = widget.movimento?.data ?? DateTime.now();
  late TipoMovimento _tipo = widget.movimento?.tipo ?? TipoMovimento.receita;
  late int? _categoriaId = widget.movimento?.categoriaId;

  late Future<List<Categoria>> _categorias;
  bool _salvando = false;
  Map<String, String> _errosApi = const {};

  bool get _edicao => widget.movimento != null;

  @override
  void initState() {
    super.initState();
    _categorias = context.read<Session>().api.listarCategorias();
  }

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(1900),
      lastDate: DateTime(2999, 12, 31),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _salvar() async {
    setState(() => _errosApi = const {});
    if (!_form.currentState!.validate()) return;

    final m = Movimento(
      id: widget.movimento?.id,
      data: _data,
      tipo: _tipo,
      descricao: _descricao.text.trim(),
      valor: fmt.parseValor(_valor.text)!,
      categoriaId: _categoriaId,
    );

    setState(() => _salvando = true);
    final api = context.read<Session>().api;
    try {
      if (_edicao) {
        await api.atualizarMovimento(m);
      } else {
        await api.criarMovimento(m);
      }
      if (!mounted) return;
      mostrarMensagem(context, _edicao ? 'Movimento atualizado.' : 'Movimento lançado.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Erros de validação (422) aparecem no próprio campo.
      if (e.details.isNotEmpty) {
        setState(() => _errosApi = e.details);
        _form.currentState!.validate();
      }
      mostrarErro(context, e);
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _remover() async {
    final m = widget.movimento!;
    if (!await confirmar(context, 'Remover movimento', 'Remover "${m.descricao}"?')) return;
    if (!mounted) return;
    setState(() => _salvando = true);
    try {
      await context.read<Session>().api.removerMovimento(m.id!);
      if (!mounted) return;
      mostrarMensagem(context, 'Movimento removido.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        mostrarErro(context, e);
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_edicao ? 'Editar movimento' : 'Novo movimento'),
        actions: [
          if (_edicao)
            IconButton(
              tooltip: 'Remover',
              onPressed: _salvando ? null : _remover,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TipoMovimento>(
              segments: const [
                ButtonSegment(
                    value: TipoMovimento.receita, label: Text('Receita'), icon: Icon(Icons.arrow_downward)),
                ButtonSegment(
                    value: TipoMovimento.despesa, label: Text('Despesa'), icon: Icon(Icons.arrow_upward)),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descricao,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe a descrição.' : _errosApi['descricao'],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: r'R$ ',
                hintText: '1.000,00',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = fmt.parseValor(v ?? '');
                if (n == null || n <= 0) return 'Informe um valor maior que zero.';
                return _errosApi['valor'];
              },
            ),
            const SizedBox(height: 16),
            FormField<DateTime>(
              validator: (_) => _errosApi['data'],
              builder: (field) => InkWell(
                onTap: _escolherData,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                    errorText: field.errorText,
                  ),
                  child: Text(fmt.data(_data)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Categoria>>(
              future: _categorias,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErroView(
                    mensagem: 'Não foi possível carregar as categorias.\n${tratarErro(context, snap.error!)}',
                    onTentarNovamente: () => setState(
                        () => _categorias = context.read<Session>().api.listarCategorias()),
                  );
                }
                final lista = snap.data;
                if (lista == null) return const LinearProgressIndicator();
                final valido = lista.any((c) => c.id == _categoriaId);
                return DropdownButtonFormField<int>(
                  initialValue: valido ? _categoriaId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                  items: [
                    for (final c in lista) DropdownMenuItem(value: c.id, child: Text(c.nome)),
                  ],
                  onChanged: (v) => setState(() => _categoriaId = v),
                  validator: (v) => v == null
                      ? (lista.isEmpty ? 'Cadastre uma categoria primeiro.' : 'Escolha a categoria.')
                      : _errosApi['categoria_id'],
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_edicao ? 'Salvar alterações' : 'Lançar'),
            ),
          ],
        ),
      ),
    );
  }
}
