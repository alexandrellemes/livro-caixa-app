import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa_app/widgets/comum.dart';

void main() {
  testWidgets('ErroView mostra a mensagem e o botão de tentar novamente', (tester) async {
    var tentou = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ErroView(mensagem: 'Falhou', onTentarNovamente: () => tentou = true)),
    ));

    expect(find.text('Falhou'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(tentou, isTrue);
  });
}
