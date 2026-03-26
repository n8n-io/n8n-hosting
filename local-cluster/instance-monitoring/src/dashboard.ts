import type { IncomingMessage, ServerResponse } from "node:http";
import { getAllRecords, type IngestRecord } from "./db.js";

function groupByInstanceId(records: IngestRecord[]): Map<string, IngestRecord[]> {
  const groups = new Map<string, IngestRecord[]>();
  for (const record of records) {
    const existing = groups.get(record.instance_id);
    if (existing) {
      existing.push(record);
    } else {
      groups.set(record.instance_id, [record]);
    }
  }
  return groups;
}

function formatDate(iso: string): string {
  return iso.replace("T", " ").replace(".000Z", "").replace("Z", "");
}

function renderHtml(groups: Map<string, IngestRecord[]>): string {
  const sections =
    groups.size === 0
      ? `<p class="empty">No data ingested yet.</p>`
      : [...groups.entries()]
          .map(([instanceId, records]) => {
            const latest = records[0];
            const identifier = latest.instance_identifier ?? "";
            const rows = records
              .map(
                (r) => `
              <tr>
                <td>${r.received_at}</td>
                <td>${r.n8n_version ?? ""}</td>
                <td>${r.total_prod_executions ?? ""}</td>
                <td>${r.interval_start ? formatDate(r.interval_start) : ""}</td>
                <td>${r.interval_end ? formatDate(r.interval_end) : ""}</td>
              </tr>`
              )
              .join("");

            return `
          <section>
            <h2>${instanceId}${identifier ? ` <span class="identifier">(${identifier})</span>` : ""}</h2>
            <table>
              <thead>
                <tr>
                  <th>Received at</th>
                  <th>n8n version</th>
                  <th>Prod executions</th>
                  <th>Interval start</th>
                  <th>Interval end</th>
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
    h2 { font-size: 1rem; margin-bottom: 1rem; word-break: break-all; }
    .identifier { font-weight: normal; color: #555; }
    table { width: 100%; border-collapse: collapse; }
    th { text-align: left; font-size: 0.8rem; color: #666; text-transform: uppercase; letter-spacing: 0.04em; padding: 0.4rem 0.75rem; border-bottom: 2px solid #e0e0e0; white-space: nowrap; }
    td { padding: 0.5rem 0.75rem; border-bottom: 1px solid #f0f0f0; font-variant-numeric: tabular-nums; }
    tr:last-child td { border-bottom: none; }
    .empty { color: #888; font-style: italic; }
  </style>
</head>
<body>
  <h1>n8n Instance Monitoring</h1>
  <p class="meta">Auto-refreshes every 30 seconds &nbsp;&bull;&nbsp; ${groups.size} instance${groups.size !== 1 ? "s" : ""}</p>
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

  let records: IngestRecord[];
  try {
    records = getAllRecords();
  } catch (err) {
    console.error("DB query error:", err);
    res.writeHead(500, { "Content-Type": "text/plain" });
    res.end("Internal server error");
    return;
  }

  const groups = groupByInstanceId(records);
  const html = renderHtml(groups);

  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(html);
}
