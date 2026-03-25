# Tour2Tour Recommendations Data Architecture

## New services

- `places-service`
  - source of truth for places catalog;
  - stores approved places, candidates, tags and import jobs;
  - will serve admin moderation workflows.

- `interactions-service`
  - stores user behavior signals;
  - captures swipes, opens, saves, shares and add-to-trip events;
  - provides aggregate summaries for ranking features.

- `recommendations-service`
  - should evolve into a pure ranking service;
  - reads from `places-service` and `interactions-service`;
  - combines survey profile with behavioral signals.

- `ingestion-service` (next step)
  - CSV import;
  - open data connectors;
  - AI-assisted tagging and de-duplication;
  - writes candidates into `places-service`.

## Data stores

- `places-db` on a separate PostgreSQL instance/server when moving to production scale.
- `interactions-db` on a separate PostgreSQL instance/server or dedicated schema if traffic stays moderate.
- `redis` for caching recommendation results and future ingestion queues.

## First production priorities

1. Move recommendations from in-memory mock places to `places-service`.
2. Start recording user interactions for every shown and swiped recommendation.
3. Build admin moderation UI on top of `places-service`.
4. Add import jobs and candidate approval flow.
5. Add ingestion workers and AI enrichment.
