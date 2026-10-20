# 0017. The NetworkPolicy allows all egress by default, and set rules replace the chart's

Date: 2026-10-20
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

In chart 1.x, `templates/networkpolicy.yaml` rendered a fixed policy and ignored `networkPolicy.ingress` and `networkPolicy.egress`. A values file that restricted ingress to one namespace still allowed port 5678 from anywhere. The fixed egress allowed DNS, the database port, the Redis port and 443. That blocked an S3-compatible store on another port, such as MinIO on 9000, and n8n does not start when it cannot reach its bucket. It also blocked workflows that call SMTP, LDAP, plain HTTP or an internal service on any other port. Values that look set but do nothing go against DESIGN.md's "Fail loudly, never silently".

## Decision

When `networkPolicy.ingress` or `networkPolicy.egress` is set, the chart renders it as given. It replaces the chart's rules for that direction and does not merge with them. Merging would mean choosing which chart rule a user rule overrides, and users could not remove a chart rule they did not want.

When a list is empty, the chart renders its own rules for that direction:

- Ingress allows the release's own pods and any source on `service.port`. The chart cannot know which namespace or labels an ingress controller uses, so a narrower default would assume a vendor. This follows DESIGN.md's "Portable primitives with portable defaults".
- Egress allows all traffic. n8n's job is calling the systems its workflows name, on whatever port they listen on, and the chart cannot know them in advance. An allow-list of ports breaks real workflows, and the user only finds out when one fails.

## Consequences

- With the policy enabled and no rules set, it restricts ingress to the n8n port and leaves egress open. Users who want tighter egress set their own list. That list has to allow DNS, the database, Redis, S3 and every system their workflows call.
- An install that set either list gets those rules after upgrading. It may lose traffic the fixed policy allowed, such as the release's own pods on 5678 or DNS.
- The chart does not derive egress rules from `s3.bucket.host`, `database.port` or `redis.port`. A user list has to name them.
- Setting `networkPolicy.enabled: false` and rendering a policy through `extraObjects` still works for platforms that manage their own policies.
