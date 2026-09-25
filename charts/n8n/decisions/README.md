# Decisions

One file per call made under `../DESIGN.md`, numbered in the order they were taken: `0001-chart-versioning.md`, `0002-....md`. The principles in DESIGN.md are the standing rules; these records are the individual calls, and they version with the chart.

These files are public, so write them for someone self-hosting n8n: the call, and enough of the why to act on it. No internal links, customer names or planning detail.

Write one when a change settles a question a reviewer could reasonably reopen later. Four short paragraphs under these headings is enough:

```markdown
# 0002. Task runners run as a sidecar by default

Date: 2026-09-21
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

What was true when the question came up, and why it needed answering.

## Decision

The call, in the present tense. Name the principle it sits under.

## Consequences

What this means for the chart, for customers upgrading, and what it closes off.
```

A decision that changes customer-visible behaviour also gets a line in `../UPGRADING.md` linking back here.
