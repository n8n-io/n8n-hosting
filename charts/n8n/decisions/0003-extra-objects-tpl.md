# 0003. extraObjects entries are rendered with tpl

Date: 2026-10-02
PR: https://github.com/n8n-io/n8n-hosting/pull/219

## Context

`extraObjects` lets a values file ship Kubernetes objects the chart knows nothing about, such as a Traefik `IngressRoute`, a Config Connector `IAMPolicyMember` or a `SecretProviderClass`. It is the passthrough DESIGN.md names for keeping the core vendor-neutral.

Many of these objects need to name things the chart creates. An `IngressRoute` points at `<fullname>-main`. A Workload Identity binding names `<namespace>/<serviceaccount>`. Those names depend on the release name, the namespace and `nameOverride`, so a hard-coded copy goes stale as soon as the same values are installed under another name.

Some objects also carry their own `{{ }}` templates, such as Prometheus alert annotations and Alertmanager message templates. Helm and these tools use the same delimiters, so the chart has to choose which one reads them first.

Three behaviours were considered:

- Emit every entry as written. Literal `{{` survives, but nothing can reference the release, and a reference written anyway reaches the cluster as literal text.
- Pass a string entry through `tpl` and emit a map entry as written. Both cases work, but which one applies depends on whether the entry is written as `- |`, and a reference inside a map still reaches the cluster as literal text.
- Pass every entry through `tpl`.

## Decision

Every `extraObjects` entry, whether a map or a YAML string, is rendered with Helm `tpl` against the release. A literal `{{` is written as `{{ "{{" }}`.

This matches `extraContainers` and `extraInitContainers` in this chart, and the extra-manifest values in the Bitnami, Argo CD, Grafana and kube-prometheus-stack charts. It sits under "Fail loudly, never silently": a missed escape usually stops the render with `undefined variable` or `nil pointer`, whereas a reference that is not expanded fails in the cluster, after install.

The chart adds the `app.kubernetes.io/name`, `instance`, `version` and `managed-by` labels to each object, and the object's own labels win. It puts an object without `metadata.namespace` in the release namespace and keeps one that is set. An entry that does not render to an object with `apiVersion`, `kind` and `metadata.name` fails validation.

## Consequences

- Examples built on `extraObjects` work for any release name and namespace without editing.
- Users who embed Prometheus, Alertmanager or Grafana templates must escape every `{{`. The README shows a worked `PrometheusRule`.
- One mistake stays silent. An unescaped `{{ .Something }}` that happens to be valid Helm syntax but matches nothing renders as an empty string. Escaping every literal `{{` avoids it.
- A cluster-scoped object without a namespace is given the release namespace. The API server ignores it for cluster-scoped kinds.
- Changing this to no `tpl` later would break every entry that relies on a reference, so it is a major-version change.
