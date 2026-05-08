<<<<<<< automated/release-v1.5.0
## [1.5.0](https://github.com/n8n-io/n8n-hosting/compare/v1.4.4...v1.5.0) (2026-05-08)

### Features

* **chart:** add per-component extraEnv for worker and webhook-processor ([#126](https://github.com/n8n-io/n8n-hosting/issues/126)) ([7dc3464](https://github.com/n8n-io/n8n-hosting/commit/7dc3464332b2f4a8a68e6103e5b9b3d06e74fe9a))
=======
## [1.4.4](https://github.com/n8n-io/n8n-hosting/compare/v1.4.3...v1.4.4) (2026-05-08)

### Bug Fixes

* **chart:** emit EXECUTIONS_DATA_PRUNE_MAX_COUNT when set to 0 ([#127](https://github.com/n8n-io/n8n-hosting/issues/127)) ([604e09c](https://github.com/n8n-io/n8n-hosting/commit/604e09c1ab0f78dc0107cacb7e44cb5ee3742774))
>>>>>>> main

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

This file is automatically managed by [semantic-release](https://github.com/semantic-release/semantic-release).
