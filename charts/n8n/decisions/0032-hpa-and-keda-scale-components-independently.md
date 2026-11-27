# 0032. Each component scales with the HPA or KEDA, not both

Date: 2026-11-27
PR: https://github.com/n8n-io/n8n-hosting/pull/307

## Context

The chart can scale workers and webhook processors with its built-in CPU HPA (`hpa.<component>`) or with KEDA (`keda.<component>`). The two components load differently. Workers back up on the Redis queue, which CPU does not show. Webhook processors are stateless HTTP pods whose load does show as CPU. So KEDA on queue depth for workers and the HPA on CPU for webhook processors is a reasonable setup.

In 1.x, `keda.enabled` switched off both HPAs, including for a component KEDA did not scale. That component then ran at its fixed replica count with no autoscaler and no warning. Where the HPA and KEDA were both set for one component, KEDA took it silently. Workers also had no flag of their own: an empty `keda.worker.triggers` was the only way to leave them off KEDA, while webhook processors had `keda.webhookProcessor.enabled`.

## Decision

Each component has one autoscaler at most, chosen per component.

- `keda.worker.enabled` switches KEDA on for workers, as `keda.webhookProcessor.enabled` does for webhook processors. It defaults to `true`, so `keda.enabled` alone still scales workers. `keda.enabled` stays as the switch for KEDA as a whole, so the `keda` block keeps its shape for existing installs.
- An HPA renders for a component unless KEDA scales it. The Deployment leaves `replicas` off whenever either one owns the count.
- `hpa.<component>.enabled` together with KEDA scaling the same component fails the render, and names both ways out. This sits under "One place to set anything, and a defined winner": two user inputs that set the same thing stop the render.
- A component with KEDA switched on and no triggers fails the render, for workers as for webhook processors, under "Fail loudly, never silently". KEDA rejects a ScaledObject without triggers, so the component would look autoscaled and not be.

## Consequences

- Upgrading from 1.x, a values file that sets both autoscalers for one component, or empties `keda.worker.triggers` with `keda.enabled`, fails until it is changed. `scripts/migrate-values.sh` makes the change and keeps the 1.x behaviour.
- An install that sets `keda.enabled` and `hpa.<component>.enabled` for a component KEDA does not scale gets a new HPA on upgrade. That Deployment runs one replica until the HPA scales it to `minReplicas`.
- The 1.x line takes only the per-component HPA, without the new flag or failures, because a new failure there would break working installs.
