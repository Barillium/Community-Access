import { createPublicGateway } from './public_gateway.mjs';

try {
  const server = await createPublicGateway({webRoot:process.argv[2],
    onSecuritySummary:summary=>console.warn(JSON.stringify(summary))});
  server.on('error', () => { console.error('Öffentliche Weiterleitung nicht gestartet.'); process.exitCode = 1; });
  server.listen(8400,'127.0.0.1',() => console.log('HTTPS-Weiterleitung lokal bereit: 127.0.0.1:8400'));
  for (const signal of ['SIGINT','SIGTERM']) process.once(signal,() => server.close());
} catch {
  console.error('Start verweigert: privaten Auth-Dienst, HTTPS-Origins und Web-Release prüfen.');
  process.exitCode = 1;
}
