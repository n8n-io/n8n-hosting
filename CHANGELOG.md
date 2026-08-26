## [1.8.0](https://github.com/n8n-io/n8n-hosting/compare/v1.7.0...v1.8.0) (2026-05-20)

### Features

* **chart:** add global chart metadata support ([#130](https://github.com/n8n-io/n8n-hosting/issues/130)) ([f25bbb4](https://github.com/n8n-io/n8n-hosting/commit/f25bbb4ff13b446da0e084fa26696fe632e478f7))

## [1.11.0](https://github.com/n8n-io/n8n-hosting/compare/v1.10.1...v1.11.0) (2026-07-17)


### Features

* **aws-cloudformation:** production-hardened ECS Fargate templates (dedicated webhook + HA tiers) ([#169](https://github.com/n8n-io/n8n-hosting/issues/169)) ([1790f0a](https://github.com/n8n-io/n8n-hosting/commit/1790f0ab75da5f69167a6dd3375ef0459fe9f5f3))
* **chart:** route /mcp to webhook processors ([#171](https://github.com/n8n-io/n8n-hosting/issues/171)) ([96349ec](https://github.com/n8n-io/n8n-hosting/commit/96349ec608eb56bd11b82e40ac9652e4ae35ab53))


### Bug Fixes

* **chart:** use correct Bull queue key bull:jobs:wait in KEDA examples ([#174](https://github.com/n8n-io/n8n-hosting/issues/174)) ([7610e08](https://github.com/n8n-io/n8n-hosting/commit/7610e084ba3321739f1e5f399dc2b711a13ffc5f))

## [1.10.1](https://github.com/n8n-io/n8n-hosting/compare/v1.10.0...v1.10.1) (2026-07-01)


### Bug Fixes

* **aws-cloudformation:** make S3 binary bucket name globally unique ([#164](https://github.com/n8n-io/n8n-hosting/issues/164)) ([926bfc7](https://github.com/n8n-io/n8n-hosting/commit/926bfc7230493bd3bf2ce8844eb601aa0e1da0b9))
* **chart:** report actual database in NOTES.txt for standalone mode ([#162](https://github.com/n8n-io/n8n-hosting/issues/162)) ([16231e3](https://github.com/n8n-io/n8n-hosting/commit/16231e3660a5ee24e79ed90eb8b90a713262afa4))


### Documentation

* clarify supported infra versions and align example image tags ([#166](https://github.com/n8n-io/n8n-hosting/issues/166)) ([2ccf1b3](https://github.com/n8n-io/n8n-hosting/commit/2ccf1b3d7eaa7fdbc5b4b287bf3252a8f14f2608))

## [1.10.0](https://github.com/n8n-io/n8n-hosting/compare/v1.9.1...v1.10.0) (2026-06-17)


### Features

* **chart:** add podLabels for pod templates ([#158](https://github.com/n8n-io/n8n-hosting/issues/158)) ([f8c056c](https://github.com/n8n-io/n8n-hosting/commit/f8c056c4fd17a27ea89d9970c2bdad9cd624e477))


### Documentation

* improve deployment guidance ([#156](https://github.com/n8n-io/n8n-hosting/issues/156)) ([f561c73](https://github.com/n8n-io/n8n-hosting/commit/f561c732b94a51a12d967849b834968fd1a4a453))

## [1.9.1](https://github.com/n8n-io/n8n-hosting/compare/v1.9.0...v1.9.1) (2026-06-15)


### Bug Fixes

* default readiness probe to /healthz/readiness ([#149](https://github.com/n8n-io/n8n-hosting/issues/149)) ([d7d2988](https://github.com/n8n-io/n8n-hosting/commit/d7d2988a2aaa376e4d392208cd61e30141696be0))
  * Pods now wait for DB connectivity and migrations before becoming Ready, instead of just for the process being alive.
  * To restore the previous behavior, set `probes.readiness.path: /healthz` in your values overrides.

## [1.9.0](https://github.com/n8n-io/n8n-hosting/compare/v1.8.0...v1.9.0) (2026-06-04)


### Features

* **chart:** add extraContainers for arbitrary sidecar injection ([#138](https://github.com/n8n-io/n8n-hosting/issues/138)) ([555704e](https://github.com/n8n-io/n8n-hosting/commit/555704ebceb1f0df974c0924a17ce86430263627))


### Bug Fixes

* **chart:** inject N8N_EDITOR_BASE_URL into containers ([#153](https://github.com/n8n-io/n8n-hosting/issues/153)) ([5f74f4a](https://github.com/n8n-io/n8n-hosting/commit/5f74f4aeefa4f528381af45d8dc468ba1cdaaa41))

## [1.7.0](https://github.com/n8n-io/n8n-hosting/compare/v1.6.1...v1.7.0) (2026-05-20)

### Features

* **chart:** add extraInitContainers, dnsPolicy/dnsConfig, and serviceAccount.automountServiceAccountToken ([#139](https://github.com/n8n-io/n8n-hosting/issues/139)) ([4109dd3](https://github.com/n8n-io/n8n-hosting/commit/4109dd355a1996f6aa3d1649bc5af46acadd3957))

## [1.6.1](https://github.com/n8n-io/n8n-hosting/compare/v1.6.0...v1.6.1) (2026-05-20)

### Bug Fixes

* **chart:** allow standalone mode with external database ([#132](https://github.com/n8n-io/n8n-hosting/issues/132)) ([40240cf](https://github.com/n8n-io/n8n-hosting/commit/40240cf18c28795e8f1f33121b32e4c74c0414e8))

## [1.6.0](https://github.com/n8n-io/n8n-hosting/compare/v1.5.1...v1.6.0) (2026-05-20)

### Features

* **chart:** add node placement per deployment ([#135](https://github.com/n8n-io/n8n-hosting/issues/135)) ([98a6d54](https://github.com/n8n-io/n8n-hosting/commit/98a6d543c6371b61db51a9a7bd5a9091d4bdf845))

## [1.5.1](https://github.com/n8n-io/n8n-hosting/compare/v1.5.0...v1.5.1) (2026-05-15)

### Documentation

* add top-level MIT LICENSE and link from README/CONTRIBUTING ([#136](https://github.com/n8n-io/n8n-hosting/issues/136)) ([34d0e63](https://github.com/n8n-io/n8n-hosting/commit/34d0e63099ec9d879df8cadc9c7777a9dd81ded2))

## [1.5.0](https://github.com/n8n-io/n8n-hosting/compare/v1.4.4...v1.5.0) (2026-05-08)

### Features

* **chart:** add per-component extraEnv for worker and webhook-processor ([#126](https://github.com/n8n-io/n8n-hosting/issues/126)) ([7dc3464](https://github.com/n8n-io/n8n-hosting/commit/7dc3464332b2f4a8a68e6103e5b9b3d06e74fe9a))

## [1.4.4](https://github.com/n8n-io/n8n-hosting/compare/v1.4.3...v1.4.4) (2026-05-08)

### Bug Fixes

* **chart:** emit EXECUTIONS_DATA_PRUNE_MAX_COUNT when set to 0 ([#127](https://github.com/n8n-io/n8n-hosting/issues/127)) ([604e09c](https://github.com/n8n-io/n8n-hosting/commit/604e09c1ab0f78dc0107cacb7e44cb5ee3742774))

## [1.4.3](https://github.com/n8n-io/n8n-hosting/compare/v1.4.2...v1.4.3) (2026-05-01)

### Bug Fixes

* **chart:** only set N8N_RUNNERS_MODE when task runners are enabled ([#121](https://github.com/n8n-io/n8n-hosting/issues/121)) ([51e8b2a](https://github.com/n8n-io/n8n-hosting/commit/51e8b2a76150ebc93fbbbd3a4635f36f6e55cc9d))

## [1.4.2](https://github.com/n8n-io/n8n-hosting/compare/v1.4.1...v1.4.2) (2026-04-23)

### Bug Fixes

* **chart:** fail fast when serviceAccount.create=false with default name ([#117](https://github.com/n8n-io/n8n-hosting/issues/117)) ([2c24b9b](https://github.com/n8n-io/n8n-hosting/commit/2c24b9b2021d836b7516118f132e2d9077cce30a))

## [1.4.1](https://github.com/n8n-io/n8n-hosting/compare/v1.4.0...v1.4.1) (2026-04-23)

### Bug Fixes

* broken form trigger and download binary from s3 ([#115](https://github.com/n8n-io/n8n-hosting/issues/115)) ([b328e4f](https://github.com/n8n-io/n8n-hosting/commit/b328e4f29ac24ad8023764884be762a6070564a2))

## [1.3.1](https://github.com/n8n-io/n8n-hosting/compare/v1.3.0...v1.3.1) (2026-04-08)

### Bug Fixes

* **chart:** allow workerReplicaCount=0 for migration-only deploys ([#109](https://github.com/n8n-io/n8n-hosting/issues/109)) ([f367807](https://github.com/n8n-io/n8n-hosting/commit/f367807b9a36e305bca12a97a151df389998ca8d))
* correct Traefik PathPrefix rule and remove stale vendor-branch refs ([#104](https://github.com/n8n-io/n8n-hosting/issues/104)) ([5d0ba6a](https://github.com/n8n-io/n8n-hosting/commit/5d0ba6a6d1c4795eeaa2bb65745d757039c71702))

## [1.3.0](https://github.com/n8n-io/n8n-hosting/compare/v1.2.0...v1.3.0) (2026-03-25)

### Features

* **chart:** support independent service annotations for main and webhook-processor ([#100](https://github.com/n8n-io/n8n-hosting/issues/100)) ([41b6345](https://github.com/n8n-io/n8n-hosting/commit/41b634523788c3fe633ab086964081e687be0169))

## [1.0.3](https://github.com/n8n-io/n8n-hosting/compare/v1.0.2...v1.0.3) (2026-03-04)

### Bug Fixes

* **ci:** add concurrency control to release workflow ([#78](https://github.com/n8n-io/n8n-hosting/issues/78)) ([e00e3b2](https://github.com/n8n-io/n8n-hosting/commit/e00e3b2b3f8485d6843198a1142175fe72b69917))

## [1.0.2](https://github.com/n8n-io/n8n-hosting/compare/v1.0.1...v1.0.2) (2026-02-25)

### Features

* **chart:** bump n8n to 2.9.2 ([#76](https://github.com/n8n-io/n8n-hosting/issues/76))

### Bug Fixes

* **ci:** remove non-existent 'automated' label from bump workflow ([#75](https://github.com/n8n-io/n8n-hosting/issues/75)) ([ce882f0](https://github.com/n8n-io/n8n-hosting/commit/ce882f093665f77be8df724e979ab4b2d159300b))

# Changelog

All notable changes to the n8n Helm chart will be documented in this file.

This file is automatically managed by [Release Please](https://github.com/googleapis/release-please).
