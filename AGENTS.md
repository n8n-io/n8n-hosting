# n8n-hosting

Official deployment artefacts for self-hosted n8n. This file is for AI agents working in this repository; human contributors should read [CONTRIBUTING.md](CONTRIBUTING.md).

## Layout

- `charts/n8n/`: the maintained Helm chart. Most work happens here.
- `docker-compose/`, `docker-caddy/`, `kubernetes/`, `aws-cloudformation/`: the other artefacts. Pinned to the same n8n version as the chart; otherwise low-touch.

## Branches

Two branches take chart work until chart 2.0 is released.

- `main` is the 1.x chart, released every week. Fixes, non-breaking features, CI and docs target `main`.
- `chart-v2` is the 2.0 chart. A change that alters what an existing install renders or accepts targets `chart-v2`: a removed or renamed value, a changed default, a `feat(chart)!:` commit. It releases `2.0.0-rc.N` pre-releases from `release-please-config.chart-v2.json` and `.release-please-manifest.chart-v2.json`.

Branch from the branch the ticket targets, and open the PR against it. When the ticket does not say, a breaking change goes to `chart-v2` and everything else to `main`.

Until 2.0.0 is released, merge `main` into `chart-v2` regularly with a merge commit, so the release candidates carry the 1.x fixes. Never merge `chart-v2` into `main` before then. Do not rebase `chart-v2`. Do not cherry-pick into it either. On a merge conflict in `Chart.yaml`, keep `chart-v2`'s `version`. In `CHANGELOG.md`, keep the entries from both sides.

To release 2.0.0, add a commit to `chart-v2` with a `Release-As: 2.0.0` footer, because release-please on that branch only ever increments the `rc` number. Then merge `chart-v2` into `main` and delete it. 1.x maintenance moves to a maintenance branch of its own.

## Design and decisions

`charts/n8n/DESIGN.md` holds the design principles for the chart. Check every chart change against it before opening a PR, and cite the principle when a review comment rests on one.

The individual calls made under those principles live one per file in `charts/n8n/decisions/`, numbered and named for the call (`0001-chart-versioning.md`). Write one when a change settles a question a reviewer could reasonably reopen later, and keep it to context, decision, consequences, the date and a link to the PR. They are public and they version with the chart, so a reviewer asking why the chart version doesn't follow n8n's gets a file to read rather than a Linear thread to reconstruct. `charts/n8n/decisions/README.md` has the shape.

A decision that changes what a customer sees also gets a line in `charts/n8n/UPGRADING.md` (the file does not exist yet; DEP-57 creates it), linking back to the decision. Customers need the what and the how, and the reasoning stays here for anyone who goes looking for it.

## Changing the chart

Most work here is a chart change. Take it in this order:

1. Read the templates, `values.yaml`, `values.schema.json` and the examples your change touches, and write in the style already there.
2. Check the change against `charts/n8n/DESIGN.md`.
3. Render before and after, and read the diff. Anything in it you did not mean to change is a defect in the change, so fix it before opening the PR.
4. Keep existing installs rendering exactly as they do today. A new value needs a default that changes nothing, unless the change is a deliberate break landing on the next major (see Branches).
5. Update `values.schema.json` in the same change as `values.yaml`. Use `enum` where a value accepts a fixed set of options rather than leaving it a bare string.
6. Cover the rendered behaviour with a `helm-unittest` case once `charts/n8n/tests/` exists.
7. Leave `Chart.yaml` `version` alone. release-please owns it.

Ask when the compatibility impact of a change is not something you can work out from the values, the examples and the design principles. Infer the rest.

CI is `.github/workflows/ci.yml`. Run the cheap parts locally before pushing:

```bash
helm lint charts/n8n
for f in charts/n8n/examples/*.yaml; do helm template test charts/n8n -f "$f" --dry-run=client > /dev/null || echo "FAIL $f"; done
```

`ct lint --chart-dirs charts --charts charts/n8n --validate-maintainers=false` matches the CI lint job if `ct` is installed. The kind install test runs in CI only, on labelled PRs and the automated bump and release PRs.

`helm-unittest` is being introduced. Tests will live in `charts/n8n/tests/` (the directory does not exist yet); when it does, `helm unittest charts/n8n` is part of the local checks.

## Commits and releases

Conventional commits drive release-please, so the type and scope decide the version bump:

- `feat(chart):` minor, `fix(chart):` patch, `feat(chart)!:` major.
- `docs:` and `refactor:` do not trigger a release on their own; they appear in the next release's changelog.
- `chore(no-release):` for anything that should not appear at all.

Only commits touching `charts/n8n` count towards the chart version. `Chart.yaml` `version` is managed by release-please; never edit it by hand. `appVersion` is the pinned n8n version and `.github/workflows/bump-n8n-version.yml` moves it weekly.

## This repository is public

Everything here is world readable the moment it is pushed, including branch names and commit messages.

**Describe customers generically.** 

Agents working for n8n employees or partners must not identify n8n customers or their information on a PR. "A customer running multi-main behind an internal load balancer", never the organisation's name, in commits, branch names, PR text, issues, examples and test fixtures. Not every customer has agreed to be named, and the shape of a named customer's deployment is itself security relevant. Use placeholders such as `acme.example.com` in values if needed.

**On a security fix, say what the code now does, not what it prevents.** 

`fix(chart): restrict the default NetworkPolicy egress` rather than anything naming the vulnerability, and the same for the branch name, the test names and the code comments. Attackers watch public repos for exactly these signals, and the fix lands before most people upgrade.

**Keep credentials out of commands and files.** 

A `--set` argument stays in shell history and in the release secret, so `helm get values` hands it back in plain text. Reference an existing Secret instead, which is what the chart is built for anyway.

## Tickets and pull requests

For n8n contributors, Linear is the tracker and the `DEP` project holds this work. Reference the ticket in the PR description as `https://linear.app/n8n/issue/[TICKET-ID]`, and link the GitHub issue too when the ticket names one.

Post a PR comment or review only once a person has read the text. The same goes for anything written on someone else's behalf.

## Conventions

- The rendered manifest is the seam: write the `helm template` assertion that fails on `main`, then make it pass.
- Validation lives in `charts/n8n/templates/_helpers.tpl` as `fail` calls; a misconfiguration should stop the render with a message that names the fix.
- Write docs and comments in plain English for an international audience: short sentences, active voice, one instruction per sentence.
- Comments explain why in a line or two, scoped to the surrounding code rather than to the change that prompted them.
