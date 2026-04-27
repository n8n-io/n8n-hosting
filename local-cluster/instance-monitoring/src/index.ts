import http from "node:http";
import { handleIngest } from "./ingest.js";
import { handleDashboard } from "./dashboard.js";

const INGEST_PORT = parseInt(process.env.INGEST_PORT ?? "5700", 10);
const DASHBOARD_PORT = parseInt(process.env.DASHBOARD_PORT ?? "5701", 10);

const ingestServer = http.createServer((req, res) => {
  handleIngest(req, res);
});

const dashboardServer = http.createServer((req, res) => {
  handleDashboard(req, res);
});

ingestServer.listen(INGEST_PORT, () => {
  console.log(`Ingest server listening on :${INGEST_PORT} (POST /ingest-data)`);
});

dashboardServer.listen(DASHBOARD_PORT, () => {
  console.log(`Dashboard server listening on :${DASHBOARD_PORT} (GET /dashboard)`);
});
