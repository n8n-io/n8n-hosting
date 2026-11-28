import { createSign, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";

function toBase64url(b: Buffer): string {
  return b.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

export function mintJWT(
  claims: Record<string, unknown>,
  privateKeyPath: string,
  kid: string
): string {
  const header = toBase64url(Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT", kid })));
  const payload = toBase64url(Buffer.from(JSON.stringify(claims)));
  const signingInput = `${header}.${payload}`;
  const sign = createSign("RSA-SHA256");
  sign.update(signingInput);
  const sig = toBase64url(sign.sign(readFileSync(privateKeyPath, "utf8")));
  return `${signingInput}.${sig}`;
}

export function buildClaims(issuer: string, audience: string): Record<string, unknown> {
  const now = Math.floor(Date.now() / 1000);
  return {
    sub: "instance-monitoring-service",
    iss: issuer,
    aud: audience,
    iat: now,
    exp: now + 300,    // 5 min — well within 15 min max TTL
    jti: randomUUID(), // unique per call — satisfies replay protection
    email: "monitoring@instance-monitoring.local",
    given_name: "Instance Monitoring",
    role: "global:admin",
  };
}
