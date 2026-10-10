import { createDashboardGateway } from './dashboard_gateway.mjs';

const server = createDashboardGateway();
server.listen(8001, '127.0.0.1', () => console.log('Dashboard-Weiterleitung bereit auf 127.0.0.1:8001'));
server.on('error', () => { console.error('Dashboard-Weiterleitung konnte nicht gestartet werden.'); process.exitCode = 1; });
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => server.close());
