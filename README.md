# Livro Caixa App (Flutter)

App Flutter para a **API REST v1** do [Livro Caixa](../../apache/projetos/livro-caixa/docs/API.md).

## Funcionalidades

| Tela | Endpoints |
|---|---|
| Login (servidor, usuário, senha) | `POST /auth/token`, `GET /auth/me` |
| Resumo do mês e geral + últimos lançamentos | `GET /resumo`, `GET /movimentos` |
| Movimentos: filtros por mês, tipo, categoria e busca, paginação infinita, lançar/editar/remover | `GET/POST/PUT/DELETE /movimentos` |
| Categorias: busca, criar/editar/remover (409 explicado quando há movimentos) | `GET/POST/PUT/DELETE /categorias` |
| Logs (só admin): filtro por nível, busca, detalhe com contexto, limpeza | `GET /logs`, `GET /logs/{id}`, `DELETE /logs` |
| Conta: perfil, tokens, revogar, sair | `GET /auth/tokens`, `DELETE /auth/tokens/{id}`, `DELETE /auth/token` |

O perfil `viewer` só consulta; os botões de alteração aparecem apenas para `admin`.
Token e URL ficam salvos no dispositivo (`shared_preferences`); um 401 leva de volta ao login.

## Executar

Plataformas configuradas: Android, Linux e Web.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d linux      # ou -d chrome, ou um dispositivo Android
```

Ícones: a imagem-fonte está em `assets/icon/`; para regenerar os ícones de Android e Web rode `dart run flutter_launcher_icons`.
O ícone da janela no Linux é `linux/runner/app_icon.png`.

### Projeto em disco NTFS (sem permissão de execução)

Se o projeto estiver num disco montado sem `exec` (ex.: NTFS via ntfs-3g), binários e scripts gerados ali não rodam:

- **Linux:** aponte `build/` para um disco Linux: `ln -s ~/.cache/livro_caixa_app_build build` (o `.gitignore` já ignora o link).
- **Android:** o `android/gradlew` também precisa executar. Monte o disco com a opção `exec` ou compile a partir de uma cópia num disco Linux.

### Endereço do servidor

| Onde o app roda | Servidor |
|---|---|
| Linux desktop / web no mesmo PC | `http://localhost:8080` |
| Emulador Android | `http://10.0.2.2:8080` (padrão no Android) |
| Celular na mesma rede | `http://IP-DO-PC:8080` |

### Android: liberar HTTP sem TLS

A API local usa `http://`, por isso o `android/app/src/main/AndroidManifest.xml` já declara a permissão `INTERNET` e `android:usesCleartextTraffic="true"`. Para produção, use HTTPS e remova essa opção.

### Web: CORS

Para rodar no navegador (`flutter run -d chrome`), defina no `.env` da API a origem do app, ex.: `API_CORS_ORIGIN=*` (somente em desenvolvimento).

## Estrutura

```
lib/
  api/api_client.dart   cliente HTTP da API (token Bearer, erros -> ApiException)
  models/               Categoria, Movimento, Resumo, LogEntry, TokenInfo, Paginado
  session.dart          login/logout e persistência do token
  screens/              telas
  widgets/              componentes comuns (erro, vazio, seletor de mês, recarga entre abas)
  util/format.dart      moeda, datas e conversão de valores pt-BR
```
