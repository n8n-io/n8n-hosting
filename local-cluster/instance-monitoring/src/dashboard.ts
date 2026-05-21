import type { IncomingMessage, ServerResponse } from "node:http";
import { getAllExecutions, type ExecutionRecord } from "./db.js";

function groupByInstance(records: ExecutionRecord[]): Map<string, ExecutionRecord[]> {
  const groups = new Map<string, ExecutionRecord[]>();
  for (const r of records) {
    const list = groups.get(r.instance_id) ?? [];
    list.push(r);
    groups.set(r.instance_id, list);
  }
  return groups;
}

function formatFetchedAt(iso: string): string {
  return iso.replace("T", " ").replace(/\.\d+Z$/, " UTC");
}

function renderHtml(groups: Map<string, ExecutionRecord[]>): string {
  const sections =
    groups.size === 0
      ? `<p class="empty">No data collected yet — waiting for first poll cycle.</p>`
      : [...groups.entries()]
          .map(([instanceId, records]) => {
            const rows = records
              .map(
                (r) => `
              <tr>
                <td>${r.day}</td>
                <td>${r.total.toLocaleString()}</td>
                <td>${r.failed.toLocaleString()}</td>
                <td>${formatFetchedAt(r.fetched_at)}</td>
              </tr>`
              )
              .join("");

            return `
          <section>
            <h2>${instanceId}</h2>
            <table>
              <thead>
                <tr>
                  <th>Day</th>
                  <th>Total executions</th>
                  <th>Failed</th>
                  <th>Last fetched</th>
                </tr>
              </thead>
              <tbody>${rows}</tbody>
            </table>
          </section>`;
          })
          .join("");

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="30">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>n8n Instance Monitoring</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, sans-serif; font-size: 14px; color: #1a1a1a; background: #f5f5f5; padding: 2rem; }
    h1 { font-size: 1.4rem; margin-bottom: 0.25rem; }
    .meta { color: #666; font-size: 0.85rem; margin-bottom: 2rem; }
    section { background: #fff; border: 1px solid #e0e0e0; border-radius: 6px; padding: 1.25rem; margin-bottom: 1.5rem; }
    h2 { font-size: 1rem; margin-bottom: 1rem; }
    table { width: 100%; border-collapse: collapse; }
    th { text-align: left; font-size: 0.8rem; color: #666; text-transform: uppercase; letter-spacing: 0.04em; padding: 0.4rem 0.75rem; border-bottom: 2px solid #e0e0e0; white-space: nowrap; }
    td { padding: 0.5rem 0.75rem; border-bottom: 1px solid #f0f0f0; font-variant-numeric: tabular-nums; }
    tr:last-child td { border-bottom: none; }
    .empty { color: #888; font-style: italic; }
  </style>
</head>
<body>
  <h1>n8n Instance Monitoring</h1>
  <p class="meta">Auto-refreshes every 30 s &nbsp;&bull;&nbsp; Pull-based via token exchange &nbsp;&bull;&nbsp; ${groups.size} instance${groups.size !== 1 ? "s" : ""}</p>
  ${sections}
</body>
</html>`;
}

export function handleDashboard(req: IncomingMessage, res: ServerResponse): void {
  if (req.url !== "/dashboard" && req.url !== "/") {
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("Not found");
    return;
  }

  let records: ExecutionRecord[];
  try {
    records = getAllExecutions();
  } catch (err) {
    console.error("DB query error:", err);
    res.writeHead(500, { "Content-Type": "text/plain" });
    res.end("Internal server error");
    return;
  }

  const groups = groupByInstance(records);
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(renderHtml(groups));
}
