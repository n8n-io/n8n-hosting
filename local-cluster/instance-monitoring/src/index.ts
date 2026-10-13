import http from "node:http";
import { handleDashboard } from "./dashboard.js";
import { pollAllInstances, type N8NInstance } from "./poller.js";

const DASHBOARD_PORT = parseInt(process.env.DASHBOARD_PORT ?? "5701", 10);
const POLL_INTERVAL_SECONDS = parseInt(process.env.POLL_INTERVAL_SECONDS ?? "90", 10);

const instances: N8NInstance[] = JSON.parse(
  process.env.N8N_INSTANCES ??
    '[{"id":"axolotl","url":"http://n8n-main.n8n-1.svc.cluster.local:5678"},' +
    '{"id":"narwhal","url":"http://n8n-main.n8n-2.svc.cluster.local:5678"},' +
    '{"id":"dolphin","url":"http://n8n-main.n8n-3.svc.cluster.local:5678"}]'
);

const privateKeyPath = process.env.TOKEN_EXCHANGE_PRIVATE_KEY_PATH ?? "/keys/private.pem";
const kid            = process.env.TOKEN_EXCHANGE_KID              ?? "instance-monitoring-key";
const issuer         = process.env.TOKEN_EXCHANGE_ISSUER           ?? "https://instance-monitoring.local";
const audience       = process.env.TOKEN_EXCHANGE_AUDIENCE         ?? "n8n";

const dashboardServer = http.createServer(handleDashboard);
dashboardServer.listen(DASHBOARD_PORT, () => {
  console.log(`Dashboard listening on :${DASHBOARD_PORT} (GET /dashboard)`);
});

async function runPoll(): Promise<void> {
  console.log("==> Poll cycle starting...");
  await pollAllInstances(instances, privateKeyPath, kid, issuer, audience);
  console.log("==> Poll cycle complete.");
}

runPoll();
setInterval(runPoll, POLL_INTERVAL_SECONDS * 1000);
