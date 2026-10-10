import { createAuth } from './auth.mjs';
import { seedDirectory } from './directory_fixtures.mjs';
import { createApp } from './http.mjs';

let state;
let server;
let stopping;
function stop() {
  stopping ??= (async () => {
    if (server) await new Promise((resolve) => server.close(resolve));
    if (state) await state.pool.end();
  })();
  return stopping;
}
try {
  state = await createAuth();
  if (process.env.CA_DIRECTORY_DEMO === 'true') await seedDirectory(state);
  server = createApp({...state,onSecuritySummary:summary=>console.warn(JSON.stringify(summary))});
  server.on('error', async () => { await stop(); process.exitCode = 1; });
  server.listen(8000, '127.0.0.1', () => console.log('Lokaler Auth-Dienst bereit: http://127.0.0.1:8000'));
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, async () => { await stop(); });
} catch {
  console.error('Lokaler Auth-Dienst konnte nicht gestartet werden. Lokale Voraussetzungen prüfen.');
  await stop();
  process.exitCode = 1;
}
