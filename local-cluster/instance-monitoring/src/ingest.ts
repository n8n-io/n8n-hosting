import type { IncomingMessage, ServerResponse } from "node:http";
import { insertRecord } from "./db.js";

export function handleIngest(req: IncomingMessage, res: ServerResponse): void {
  if (req.method !== "POST" || req.url !== "/ingest-data") {
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found" }));
    return;
  }

  let body = "";
  req.on("data", (chunk) => {
    body += chunk.toString();
  });

  req.on("end", () => {
    let payload: unknown;
    try {
      payload = JSON.parse(body);
    } catch {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Invalid JSON" }));
      return;
    }

    if (
      typeof payload !== "object" ||
      payload === null ||
      typeof (payload as Record<string, unknown>).instanceId !== "string" ||
      typeof (payload as Record<string, unknown>).n8nVersion !== "string" ||
      typeof (payload as Record<string, unknown>).data !== "object" ||
      (payload as Record<string, unknown>).data === null ||
      typeof ((payload as Record<string, unknown>).data as Record<string, unknown>).rootExecutionsTotal !== "number"
    ) {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Missing required fields: instanceId, n8nVersion, data.rootExecutionsTotal" }));
      return;
    }

    const p = payload as Record<string, unknown>;
    const data = p.data as Record<string, unknown>;

    try {
      insertRecord({
        instance_id: p.instanceId as string,
        instance_identifier: typeof p.instanceIdentifier === "string" ? p.instanceIdentifier : null,
        n8n_version: p.n8nVersion as string,
        total_prod_executions: data.rootExecutionsTotal as number,
      });
    } catch (err) {
      console.error("DB insert error:", err);
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Internal server error" }));
      return;
    }

    res.writeHead(201, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
  });
}
