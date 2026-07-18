import type { IncomingMessage, ServerResponse } from "node:http";
import { readFileSync } from "node:fs";
import path from "node:path";
import { getAllExecutions, type ExecutionRecord } from "./db.js";

interface InstanceSummary {
  id: string;
  total: number;
  success: number;
  error: number;
  trackingSince: string;
  byDay: { day: string; success: number; error: number }[];
}

function isoToDMY(iso: string): string {
  const [y, m, d] = iso.split("-");
  return `${d}.${m}.${y}`;
}

function groupByInstance(records: ExecutionRecord[]): Map<string, ExecutionRecord[]> {
  const groups = new Map<string, ExecutionRecord[]>();
  for (const r of records) {
    const list = groups.get(r.instance_id) ?? [];
    list.push(r);
    groups.set(r.instance_id, list);
  }
  return groups;
}

function computeSummaries(groups: Map<string, ExecutionRecord[]>): InstanceSummary[] {
  const summaries: InstanceSummary[] = [];
  for (const [id, records] of groups) {
    let total = 0;
    let error = 0;
    // records are ordered day DESC; last element is the earliest day
    const trackingSince = isoToDMY(records[records.length - 1].day);
    const byDay = records.map((r) => {
      total += r.total;
      error += r.failed;
      return { day: isoToDMY(r.day), success: r.total - r.failed, error: r.failed };
    });
    summaries.push({ id, total, success: total - error, error, trackingSince, byDay });
  }
  summaries.sort((a, b) => b.total - a.total);
  return summaries;
}

const css = readFileSync(path.join(__dirname, "dashboard.css"), "utf8");

function renderHtml(summaries: InstanceSummary[]): string {
  const listItems =
    summaries.length === 0
      ? `<p class="empty">No data collected yet — waiting for first poll cycle.</p>`
      : summaries
          .map(
            (s, i) => `
        <div class="list-item" data-idx="${i}">
          <span class="name">${s.id}</span>
          <span class="count">${s.total.toLocaleString("de-DE")}</span>
        </div>`
          )
          .join("");

  const instancesJson = JSON.stringify(summaries);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="30">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>n8n Instance Monitoring</title>
  <link rel="stylesheet" href="/dashboard.css">
</head>
<body>
  <h1>n8n Instance Monitoring</h1>
  <p class="meta">Auto-refreshes every 30 s &nbsp;&bull;&nbsp; Pull-based via token exchange &nbsp;&bull;&nbsp; ${summaries.length} instance${summaries.length !== 1 ? "s" : ""}</p>
  <div class="layout">
    <div class="list-panel" id="list">${listItems}</div>
    <div class="detail-panel" id="detail" hidden></div>
  </div>
  <script>
    const INSTANCES = ${instancesJson};

    function fmt(n) { return n.toLocaleString('de-DE'); }

    function renderDetail(inst) {
      const rows = inst.byDay.map(d =>
        '<tr>' +
        '<td>' + d.day + '</td>' +
        '<td class="success">' + fmt(d.success) + '</td>' +
        '<td class="error">' + fmt(d.error) + '</td>' +
        '</tr>'
      ).join('');
      return '<button class="close-btn" id="close-btn" aria-label="Close">&times;</button>' +
        '<h2>' + inst.id + '</h2>' +
        '<dl>' +
        '<dt>Tracking since</dt><dd>' + inst.trackingSince + '</dd>' +
        '<dt>Successful executions</dt><dd class="success">' + fmt(inst.success) + '</dd>' +
        '<dt>Error executions</dt><dd class="error">' + fmt(inst.error) + '</dd>' +
        '</dl>' +
        '<h3>Count by day</h3>' +
        '<table><tbody>' + rows + '</tbody></table>';
    }

    document.getElementById('detail').addEventListener('click', function(e) {
      if (e.target.id !== 'close-btn') return;
      document.getElementById('detail').hidden = true;
      document.querySelectorAll('.list-item').forEach(function(el) { el.classList.remove('selected'); });
    });

    document.getElementById('list').addEventListener('click', function(e) {
      var item = e.target.closest('.list-item');
      if (!item) return;
      document.querySelectorAll('.list-item').forEach(function(el) { el.classList.remove('selected'); });
      item.classList.add('selected');
      var inst = INSTANCES[+item.dataset.idx];
      var panel = document.getElementById('detail');
      panel.hidden = false;
      panel.innerHTML = renderDetail(inst);
    });
  </script>
</body>
</html>`;
}

export function handleDashboard(req: IncomingMessage, res: ServerResponse): void {
  if (req.url === "/dashboard.css") {
    res.writeHead(200, { "Content-Type": "text/css; charset=utf-8" });
    res.end(css);
    return;
  }

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
  const summaries = computeSummaries(groups);
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(renderHtml(summaries));
}
