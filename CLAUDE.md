# n8n-hosting

Official deployment artefacts for self-hosted n8n.

## Layout

- `charts/n8n/`: the maintained Helm chart. Most work happens here.
- `docker-compose/`, `docker-caddy/`, `kubernetes/`, `aws-cloudformation/`: the other artefacts. Pinned to the same n8n version as the chart; otherwise low-touch.

## Chart design authority

`charts/n8n/DESIGN.md` holds the design principles for the chart. Check every chart change against it before opening a PR, and cite the principle when a review comment rests on one.

## Commits and releases

Conventional commits drive release-please, so the type and scope decide the version bump:

- `feat(chart):` minor, `fix(chart):` patch, `feat(chart)!:` major.
- `docs:` and `refactor:` do not trigger a release on their own; they appear in the next release's changelog.
- `chore(no-release):` for anything that should not appear at all.

Only commits touching `charts/n8n` count towards the chart version. `Chart.yaml` `version` is managed by release-please; never edit it by hand. `appVersion` is the pinned n8n version and `.github/workflows/bump-n8n-version.yml` moves it weekly.

## Checks

CI is `.github/workflows/ci.yml`. Run the cheap parts locally before pushing:

```bash
helm lint charts/n8n
for f in charts/n8n/examples/*.yaml; do helm template test charts/n8n -f "$f" --dry-run=client > /dev/null || echo "FAIL $f"; done
```

`ct lint --chart-dirs charts --charts charts/n8n --validate-maintainers=false` matches the CI lint job if `ct` is installed. The kind install test runs in CI only, on labelled PRs and the automated bump and release PRs.

`helm-unittest` is being introduced. Tests will live in `charts/n8n/tests/` (the directory does not exist yet); when it does, `helm unittest charts/n8n` is part of the local checks.

## Conventions

- The rendered manifest is the seam: write the `helm template` assertion that fails on `main`, then make it pass.
- Validation lives in `charts/n8n/templates/_helpers.tpl` as `fail` calls; a misconfiguration should stop the render with a message that names the fix.
- British English in docs and comments.
