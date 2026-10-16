# 0020. Retired values keys fail the render

Date: 2026-10-14
PR: https://github.com/n8n-io/n8n-hosting/pull/247

## Context

Chart 2.0 removes and renames several values keys. Helm passes on any key a values file sets, even one no template reads. So an install that upgrades with a 1.x values file would render without error, and the settings behind the removed keys would stop applying without a word.

The schema can reject unknown keys, but its message is a generic JSON Schema error. It cannot say what replaced the key.

## Decision

The chart keeps one list of retired keys in `n8n.retiredKeys`, each with a sentence naming its replacement. `n8n.validate` fails the render on every listed key that a values file sets, and reports them all in one render. This sits under "Upgrades are in place, across majors included" and "Fail loudly, never silently".

A key counts as set when its path is present in the values, whatever its value. A key is added to the list in the same change that removes it from `values.yaml`. Retired keys stay declared in `values.schema.json`, described as retired, so this message is the one a user sees rather than the schema's.

The chart fails rather than warns. A warning in `NOTES.txt` appears after the upgrade has already applied, and CI and Argo CD do not show it.

## Consequences

- Upgrading to 2.0 with an unchanged 1.x values file fails before anything is applied, with a list of what to change. `UPGRADING.md` explains each change.
- A values file shared between 1.x and 2.0 installs cannot keep a retired key. Each line needs its own values file.
- The list only grows within a major. Entries can be dropped in a later major, once no supported upgrade path starts from a version that had the key.
