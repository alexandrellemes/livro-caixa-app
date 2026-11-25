import 'package:intl/intl.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _data = DateFormat('dd/MM/yyyy', 'pt_BR');
final _dataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
final _mesAno = DateFormat('MMMM yyyy', 'pt_BR');

String moeda(num v) => _moeda.format(v);
String data(DateTime d) => _data.format(d);
String dataHora(DateTime? d) => d == null ? '—' : _dataHora.format(d);

String mesAno(int mes, int ano) {
  final s = _mesAno.format(DateTime(ano, mes));
  return s[0].toUpperCase() + s.substring(1);
}

/// Converte "1.234,56", "1234.56" ou "R$ 10" em número; null se inválido.
double? parseValor(String texto) {
  var t = texto.replaceAll(RegExp(r'[^\d,.]'), '');
  if (t.isEmpty) return null;
  final ultimo = t.lastIndexOf(RegExp(r'[,.]'));
  if (ultimo >= 0 && t.length - ultimo - 1 <= 2) {
    t = '${t.substring(0, ultimo).replaceAll(RegExp(r'[,.]'), '')}.${t.substring(ultimo + 1)}';
  } else {
    t = t.replaceAll(RegExp(r'[,.]'), '');
  }
  return double.tryParse(t);
}

/// Valor no formato de edição pt-BR, sem símbolo: 1234.5 -> "1.234,50".
String valorEditavel(double v) => NumberFormat('#,##0.00', 'pt_BR').format(v);
