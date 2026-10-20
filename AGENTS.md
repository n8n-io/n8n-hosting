# n8n-hosting

Official deployment artefacts for self-hosted n8n. This file is for AI agents working in this repository; human contributors should read [CONTRIBUTING.md](CONTRIBUTING.md).

## Layout

- `charts/n8n/`: the maintained Helm chart. Most work happens here.
- `docker-compose/`, `docker-caddy/`, `kubernetes/`, `aws-cloudformation/`: the other artefacts. Pinned to the same n8n version as the chart; otherwise low-touch.

## Branches

Each n8n major has a chart line, and each line has a branch.

- `main` is chart 2.0, which ships with n8n 3.0. It releases `2.0.0-rc.N` until 2.0.0 ships. Breaking changes land here.
- `release/n8n-2.x` is chart 1.x, for n8n 2.x. It takes fixes and additive features only, and never a breaking change.

Branch from `main` and open the PR against it. The exception is a fix for code that exists only on a maintenance branch, for example a values key that `main` has removed. Branch from the maintenance branch, open the PR against it, and say in the description why the fix is not on `main`.

A change that also applies to 1.x reaches it as a backport. Add the label `backport release/n8n-2.x` to the PR on `main`, before or after it merges. `.github/workflows/backport.yml` cherry-picks the merged commit and opens a PR against the maintenance branch with the same title. It refuses a breaking change. If the cherry-pick conflicts, it says so on the original PR, and the backport is then a PR against the maintenance branch written by hand.

Each branch runs its own copy of `.github/workflows/`. The exception is `bump-n8n-version.yml`, which runs from `main` and opens a bump PR for every line. Change workflows on `main`. Bring a change to a maintenance branch only when it changes what CI or a release does on that branch, as a PR of its own. The backport label cannot do this, because the App it pushes with has no permission to change workflow files. A job that acts only on `main`, such as `upgrade-test`, stays on `main`. Each branch also keeps its own `release-please-config.json` and `.release-please-manifest.json`.

## Design and decisions

`charts/n8n/DESIGN.md` holds the design principles for the chart. Check every chart change against it before opening a PR, and cite the principle when a review comment rests on one.

The individual calls made under those principles live one per file in `charts/n8n/decisions/`, numbered and named for the call (`0001-chart-versioning.md`). Take the next free number when work on the change starts, and record it on the ticket, so that two open PRs never claim the same number. Write one when a change settles a question a reviewer could reasonably reopen later, and keep it to context, decision, consequences, the date and a link to the PR. They are public and they version with the chart, so a reviewer asking why the chart version doesn't follow n8n's gets a file to read rather than a Linear thread to reconstruct. `charts/n8n/decisions/README.md` has the shape.

A decision that changes what a customer sees also gets a line in `charts/n8n/UPGRADING.md`, under the heading for its topic, linking back to the decision. Customers need the what and the how, and the reasoning stays here for anyone who goes looking for it.

## Changing the chart

Most work here is a chart change. Take it in this order:

1. Read the templates, `values.yaml`, `values.schema.json` and the examples your change touches, and write in the style already there.
2. Check the change against `charts/n8n/DESIGN.md`.
3. Render before and after, and read the diff. Anything in it you did not mean to change is a defect in the change, so fix it before opening the PR.
4. Decide whether the change is breaking. A change is breaking when an install that works today needs new values or manual steps to upgrade. Breaking changes land on a major as `feat(chart)!:`.
   - Breaking: renaming or removing a values key, adding a value with no working default, changing an immutable field (selectors, resource names, StatefulSet `volumeClaimTemplates`), and raising the minimum Kubernetes version.
   - Not breaking: pods rolling on upgrade, which is how `helm upgrade` works here. A bug fix that makes the chart do what its values already say. A new `fail` that rejects a combination of values that never worked, because those installs were already broken and the message names the fix.
   - Take care when changing a default. A new default that meaningfully changes a deployment's performance or behaviour, in a way a user would not reasonably expect from a minor or patch release, belongs on a major.
   - Give a new value a default that leaves today's render unchanged.
   - When you remove or rename a values key, add it to `n8n.retiredKeys` in `_helpers.tpl` with its replacement, in the same change. Keep it declared in `values.schema.json`, described as retired.
   - Call out a roll or a new `fail` in the PR description so it reaches the changelog.
   - A breaking change carries its own upgrade path in the same PR: a guard entry that fails the render on each retired key and names its replacement, the lines in `charts/n8n/UPGRADING.md` that tell users what to change, and the examples migrated to the new values.
5. Update `values.schema.json` in the same change as `values.yaml`. Use `enum` where a value accepts a fixed set of options rather than leaving it a bare string.
6. Cover the rendered behaviour with a `helm-unittest` case in `charts/n8n/tests/`. A new `fail` in `n8n.validate` gets a `failedTemplate` case and a passing case for the valid shape.
7. Leave `Chart.yaml` `version` alone. release-please owns it.

Ask when you cannot show that the input a new `fail` rejects never worked, or when a change sits outside the lists in step 4. Infer the rest.

CI is `.github/workflows/ci.yml`. Run the cheap parts locally before pushing:

```bash
helm lint charts/n8n
for f in charts/n8n/examples/*.yaml; do helm template test charts/n8n -f "$f" --dry-run=client > /dev/null || echo "FAIL $f"; done
helm unittest --strict charts/n8n
helm unittest --strict --skip-schema-validation -f 'tests/without-schema/*_test.yaml' charts/n8n
```

`ct lint --chart-dirs charts --charts charts/n8n --validate-maintainers=false` matches the CI lint job if `ct` is installed. The kind install test runs in CI only, on labelled PRs and the automated bump and release PRs. On PRs to `main`, the `test-install-v3-rc` label runs it on the newest n8n 3 release candidate. The kind upgrade test, from the last release of the previous major to the PR, runs in CI only, on PRs to `main` labelled `test-upgrade`.

The unit tests need the `helm-unittest` plugin at the version CI pins in the `unittest` job. Where `values.schema.json` rejects an input before the templates render, assert the schema error in the main suite and the `fail` message in `tests/without-schema/`. `tests/default-render_test.yaml` snapshots the default output. When a change alters that output on purpose, run `helm unittest -u charts/n8n` and commit the updated snapshot with the change.

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

Write the PR description in the sections of `.github/pull_request_template.md`. Tick only the boxes you have checked.

For n8n contributors, Linear is the tracker and the `DEP` project holds this work. Reference the ticket in the PR description as `https://linear.app/n8n/issue/[TICKET-ID]`, and link the GitHub issue too when the ticket names one.

Post a PR comment or review only once a person has read the text. The same goes for anything written on someone else's behalf.

## Conventions

- The rendered manifest is the seam: write the `helm template` assertion that fails on `main`, then make it pass.
- Validation lives in `charts/n8n/templates/_helpers.tpl` as `fail` calls; a misconfiguration should stop the render with a message that names the fix.
- Write docs and comments in plain English for an international audience: short sentences, active voice, one instruction per sentence.
- Comments explain why in a line or two, scoped to the surrounding code rather than to the change that prompted them.
