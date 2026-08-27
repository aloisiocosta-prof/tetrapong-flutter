# TetraPong

Protótipo jogável Flutter do TetraPong, baseado no GDD, no Design System Atomic Design, nos diagramas C4/UML 2.x e no pacote visual gerado do projeto.

## Core loop

O jogador move o paddle para interceptar o tetraminó. Um `HIT` rebate a peça e aumenta a pressão. Um `MISS` reinicia a trajetória e adiciona uma penalidade ao board do jogador atingido. O board pode limpar linhas e recuperar espaço; quando o board alcança overflow, a partida termina com `VICTORY` ou `DEFEAT`.

## Plataformas

O código usa APIs Flutter/Dart compartilhadas no protótipo e foi preparado para compilação Web e WebAssembly. A camada de gameplay usa `CustomPainter`, `ChangeNotifier`, timer determinístico de atualização e widgets Material para HUD e telas.

## Execução local

```bash
export PATH=/home/ubuntu/flutter/bin:$PATH
flutter pub get
flutter run -d chrome
```

Para ambientes em que o executável é Chromium:

```bash
CHROME_EXECUTABLE=/usr/bin/chromium flutter run -d chrome
```

## Testes e builds

```bash
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
flutter build web --release
flutter build web --wasm --release
```

O build WebAssembly é uma capacidade nova do Flutter e deve ser validado em navegadores-alvo antes de produção. O pipeline executa análise, testes, cobertura, build Web e build Wasm em pull requests e pushes para `main`/`develop`.

## GitHub Pages

O workflow `.github/workflows/ci.yml` publica automaticamente o conteúdo de `build/web` no GitHub Pages após cada push aprovado em `main`, usando o ambiente `github-pages`. A URL esperada é `https://aloisiocosta-prof.github.io/tetrapong-flutter/`. Para a primeira publicação, a fonte **Settings → Pages → Build and deployment → Source → GitHub Actions** precisa estar habilitada no repositório; o token de automação disponível não possui permissão administrativa para ativar essa configuração via API.

## Estrutura atual

| Caminho | Responsabilidade |
|---|---|
| `lib/main.dart` | Protótipo integrado com domínio, estado, simulação, HUD e telas. |
| `assets/` | Assets visuais, spritesheets, ícones e trilha gerados para o TetraPong. |
| `.github/workflows/ci.yml` | Qualidade, testes, cobertura, builds e deploy GitHub Pages. |
| `.github/workflows/security.yml` | Gitleaks, auditoria de dependências e Trivy. |
| `test/widget_test.dart` | Testes de menu e navegação básica. |

## DevSecOps

O repositório usa GitHub Actions com permissões mínimas, análise de formato, análise estática, testes, cobertura, artefatos de build, varredura de segredos e varredura de vulnerabilidades no filesystem. A proteção de branch, revisão obrigatória, Dependabot e secret scanning nativo devem ser habilitados nas configurações do repositório após sua criação.

## Próximas evoluções

A próxima etapa deve separar `domain`, `application`, `infrastructure/platform` e `presentation`, substituir o timer de protótipo por um clock injetável, adicionar testes de colisão e penalidade, integrar áudio por adaptador, recortar os spritesheets em frames de runtime e criar adaptadores Android/Web conforme a governança arquitetural do GDD.
