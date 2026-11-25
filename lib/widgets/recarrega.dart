import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../session.dart';

/// Chama [recarregar] quando outra tela avisar `Session.dadosAlterados()`.
mixin RecarregaAoAlterar<T extends StatefulWidget> on State<T> {
  late final Session _session;
  late int _versao;

  void recarregar();

  void _ouvir() {
    if (_session.versaoDados != _versao) {
      _versao = _session.versaoDados;
      if (mounted) recarregar();
    }
  }

  @override
  void initState() {
    super.initState();
    _session = context.read<Session>();
    _versao = _session.versaoDados;
    _session.addListener(_ouvir);
  }

  @override
  void dispose() {
    _session.removeListener(_ouvir);
    super.dispose();
  }
}
