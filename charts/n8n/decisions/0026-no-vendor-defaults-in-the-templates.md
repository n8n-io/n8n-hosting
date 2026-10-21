# 0026. The templates set no ingress controller or cloud annotations

Date: 2026-10-21
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

In 1.x, `ingress.sticky` added ingress-nginx cookie affinity annotations to the main Ingress, and `serviceAccount.awsRoleArn` added the EKS IRSA annotation to the ServiceAccount. Each one served a single controller or a single cloud. Kubernetes announced the retirement of ingress-nginx in November 2025. Users on Traefik, an ALB, GKE or AKS had keys that did nothing for them, and `s3.auth.autoDetect` required `awsRoleArn` even where the pod got its AWS identity another way, such as EKS Pod Identity.

## Decision

Under "Portable primitives with portable defaults" in `../DESIGN.md`, nothing in `templates/` names an ingress controller or a cloud. `ingress.sticky` and `serviceAccount.awsRoleArn` are retired. Controller and cloud settings arrive through `ingress.annotations` and `serviceAccount.annotations`, and the examples show them: `examples/https-ingress.yaml` for ingress-nginx cookie affinity, and `examples/production-s3.yaml` for IRSA.

`s3.auth.autoDetect` stays. It sets n8n's `N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT`, which tells the AWS SDK to find credentials itself. That works with IRSA, Pod Identity, node roles and environment credentials, so it is not tied to one platform. It no longer requires `awsRoleArn`.

## Consequences

The default render does not change. An install that sets either retired key fails the render with a message that names the annotation to set instead, so nobody loses affinity or their IAM role silently on upgrade. `service.sessionAffinity` stays as the portable alternative to controller affinity. A new controller or cloud needs a new example, not a change to the templates.
