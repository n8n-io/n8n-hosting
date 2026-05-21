import { DatabaseSync } from "node:sqlite";
import path from "node:path";

const dbPath = process.env.DB_PATH ?? path.join(process.cwd(), "monitoring.db");
const db = new DatabaseSync(dbPath);

db.exec(`
  CREATE TABLE IF NOT EXISTS instance_executions (
    instance_id  TEXT NOT NULL,
    day          TEXT NOT NULL,
    total        INTEGER NOT NULL,
    failed       INTEGER NOT NULL,
    fetched_at   TEXT NOT NULL,
    PRIMARY KEY (instance_id, fetched_at)
  )
`);

export interface ExecutionRecord {
  instance_id: string;
  day: string;
  total: number;
  failed: number;
  fetched_at: string;
}

const insertStmt = db.prepare(`
  INSERT OR REPLACE INTO instance_executions (instance_id, day, total, failed, fetched_at)
  VALUES (@instance_id, @day, @total, @failed, @fetched_at)
`);

const selectAllStmt = db.prepare(
  "SELECT * FROM instance_executions ORDER BY instance_id ASC, fetched_at DESC"
);

const latestFetchedAtStmt = db.prepare(
  "SELECT MAX(fetched_at) AS latest FROM instance_executions WHERE instance_id = ?"
);

export function getLatestFetchedAt(instanceId: string): string | null {
  const row = latestFetchedAtStmt.get(instanceId) as { latest: string | null } | undefined;
  return row?.latest ?? null;
}

export function upsertExecution(data: ExecutionRecord): void {
  insertStmt.run(data as unknown as Record<string, number | string>);
}

export function getAllExecutions(): ExecutionRecord[] {
  return selectAllStmt.all() as unknown as ExecutionRecord[];
}
