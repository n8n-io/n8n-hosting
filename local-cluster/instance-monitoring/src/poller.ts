import { mintJWT, buildClaims } from "./jwt.js";
import { upsertExecution, getLatestFetchedAt } from "./db.js";

export interface N8NInstance {
  id: string;
  url: string;
}

interface SummaryResponse {
  total: { value: number };
  failed: { value: number };
}

async function exchangeToken(
  instanceUrl: string,
  privateKeyPath: string,
  kid: string,
  issuer: string,
  audience: string
): Promise<string> {
  const claims = buildClaims(issuer, audience);
  const jwt = mintJWT(claims, privateKeyPath, kid);
  const res = await fetch(`${instanceUrl}/rest/auth/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
      subject_token: jwt,
    }).toString(),
  });
  if (!res.ok) {
    throw new Error(`Token exchange HTTP ${res.status}: ${await res.text()}`);
  }
  return ((await res.json()) as { access_token: string }).access_token;
}

async function pollInstance(
  instance: N8NInstance,
  privateKeyPath: string,
  kid: string,
  issuer: string,
  audience: string
): Promise<void> {
  const now = new Date();
  const day = now.toISOString().slice(0, 10);
  const lastFetchedAt = getLatestFetchedAt(instance.id);
  const startDate = lastFetchedAt
    ? lastFetchedAt
    : new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000).toISOString();
  const endDate = now.toISOString();
  console.log(`[${instance.id}] Polling insights from ${startDate} to ${endDate}...`);
  try {
    const token = await exchangeToken(instance.url, privateKeyPath, kid, issuer, audience);
    const url =
      `${instance.url}/api/v1/insights/summary` +
      `?startDate=${encodeURIComponent(startDate)}&endDate=${encodeURIComponent(endDate)}`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!res.ok) {
      throw new Error(`Insights API HTTP ${res.status}: ${await res.text()}`);
    }
    const data = (await res.json()) as SummaryResponse;
    upsertExecution({
      instance_id: instance.id,
      day,
      total: data.total.value,
      failed: data.failed.value,
      fetched_at: now.toISOString(),
    });
    console.log(`[${instance.id}] Upserted: total=${data.total.value} failed=${data.failed.value}`);
  } catch (err) {
    console.error(`[${instance.id}] Poll error:`, err);
  }
}

export async function pollAllInstances(
  instances: N8NInstance[],
  privateKeyPath: string,
  kid: string,
  issuer: string,
  audience: string
): Promise<void> {
  await Promise.all(
    instances.map((i) => pollInstance(i, privateKeyPath, kid, issuer, audience))
  );
}
