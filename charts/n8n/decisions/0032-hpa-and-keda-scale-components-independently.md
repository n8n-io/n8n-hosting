# 0032. The HPA and KEDA scale each component independently

Date: 2026-11-26
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

The chart can scale workers and webhook processors with its built-in CPU HPA (`hpa.<component>`) or with KEDA (`keda.<component>`). The two components load differently. Workers back up on the Redis queue, which CPU does not show. Webhook processors are stateless HTTP pods whose load does show as CPU. So KEDA on queue depth for workers and the HPA on CPU for webhook processors is a reasonable setup. `keda.enabled` switched off both HPAs, including for a component KEDA did not scale. That component then ran at its fixed replica count with no autoscaler and no warning.

## Decision

An HPA renders for a component unless KEDA scales that component. "KEDA scales it" means a `ScaledObject` renders for it, which needs `keda.enabled`, queue mode and at least one trigger for the component. The Deployment leaves `replicas` off whenever either autoscaler owns the count. This sits under "Fail loudly, never silently": `hpa.<component>.enabled` now does what it says for every component KEDA leaves alone.

Where `hpa.<component>.enabled` and KEDA are both set for one component, KEDA scales it and no HPA renders. The chart does not fail on that combination, although the same principle points that way. The combination renders on 1.x, and this change reaches 1.x as a fix, where a new failure would break working installs.

## Consequences

- Each component has one autoscaler at most. The chart never renders an HPA and a `ScaledObject` for the same Deployment.
- An install that sets `keda.enabled` and `hpa.<component>.enabled` for a component KEDA does not scale gets a new HPA on upgrade. The HPA takes over `replicas`, so that Deployment runs one replica until the HPA scales it to `minReplicas`.
- An `hpa.<component>.enabled: true` that KEDA overrides still renders without a message. A later major could reject it.
