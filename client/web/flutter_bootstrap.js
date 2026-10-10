{{flutter_js}}
{{flutter_build_config}}

window.addEventListener("flutter-first-frame", () => {
  document.documentElement.lang = "de";
}, { once: true });

_flutter.loader.load({
  config: {
    // Renderer assets must be bundled with --no-web-resources-cdn.
    canvasKitBaseUrl: "canvaskit/",
    fontFallbackBaseUrl: "assets/font-fallback/",
  },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      // Flutter initially copies the browser locale; this interface is German.
      document.documentElement.lang = "de";
      document.getElementById("startup")?.remove();
    } catch (_) {
      document.getElementById("startup").textContent =
        "Community Access konnte nicht geladen werden. Bitte lade die Seite erneut.";
    }
  },
});
