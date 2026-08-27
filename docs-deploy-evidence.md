# Evidências de Deploy Web/Wasm/PWA

A documentação oficial do GitHub recomenda workflows customizados quando existe um processo de build próprio; o fluxo usa `actions/configure-pages`, `actions/upload-pages-artifact` e `actions/deploy-pages`. O job de deploy requer `pages: write`, `id-token: write`, uma relação `needs` com o job de build e o ambiente `github-pages`.

O Flutter documenta que `flutter build web --wasm` gera a saída no diretório `build/web`, e que o app pode manter fallback JavaScript quando o navegador não oferece WasmGC. O Flutter também informa que não gera ou gerencia service worker por padrão, portanto o projeto adiciona um service worker PWA próprio.

## Referências

1. https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages — Using custom workflows with GitHub Pages.
2. https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site — Configuring a publishing source for your GitHub Pages site.
3. https://docs.flutter.dev/platform-integration/web/wasm — Support for WebAssembly (Wasm).
4. https://docs.flutter.dev/platform-integration/web/faq — Web FAQ, incluindo service worker e deploy.
