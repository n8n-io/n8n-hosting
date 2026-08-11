import { DatabaseSync } from "node:sqlite";
import path from "node:path";

const dbPath = process.env.DB_PATH ?? path.join(process.cwd(), "monitoring.db");
const db = new DatabaseSync(dbPath);

db.exec(`
  CREATE TABLE IF NOT EXISTS ingest_records (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    instance_id           TEXT NOT NULL,
    instance_identifier   TEXT,
    n8n_version           TEXT,
    total_prod_executions INTEGER,
    received_at           TEXT NOT NULL DEFAULT (datetime('now'))
  )
`);

export interface IngestRecord {
  id: number;
  instance_id: string;
  instance_identifier: string | null;
  n8n_version: string | null;
  total_prod_executions: number | null;
  received_at: string;
}

const insertStmt = db.prepare(`
  INSERT INTO ingest_records
    (instance_id, instance_identifier, n8n_version, total_prod_executions)
  VALUES
    (@instance_id, @instance_identifier, @n8n_version, @total_prod_executions)
`);

const selectAllStmt = db.prepare(
  "SELECT * FROM ingest_records ORDER BY instance_id ASC, received_at DESC"
);

export function insertRecord(data: {
  instance_id: string;
  instance_identifier: string | null;
  n8n_version: string;
  total_prod_executions: number;
}): void {
  insertStmt.run(data as Record<string, number | string | null>);
}

export function getAllRecords(): IngestRecord[] {
  return selectAllStmt.all() as unknown as IngestRecord[];
}
