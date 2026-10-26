# ReStock architecture (MVP)

## Shape

ReStock is a modular monolith: a Rails 7.1 API backed by PostgreSQL and a React + TypeScript + Vite single-page application. The browser calls versioned JSON endpoints under `/api/v1`. The frontend does not make direct database calls.

## Backend responsibilities

- Controllers handle HTTP parameters, status codes, and JSON serialization.
- Active Record models define associations and validation rules.
- `Returns::RecordDisposition` coordinates the disposition workflow in a database transaction.
- PostgreSQL constraints protect key quantity, status, and uniqueness invariants.
- Inventory movements are a ledger of disposition-driven stock changes.
- Audit events record key return lifecycle actions.

## Inventory transaction

A disposition locks the return row, checks the completed inspection and restock eligibility, creates a disposition, updates the appropriate inventory bucket, records a uniquely keyed movement, completes the return, and writes an audit event in one transaction. A failure rolls back the whole transaction. A unique disposition per return and unique movement idempotency key prevent duplicate stock changes.

## Frontend responsibilities

The React UI presents overview metrics, products, return registration and receipt, and inventory buckets. It uses a small typed fetch wrapper and reads the API base URL from `VITE_API_BASE_URL`.

## Known gaps

Bearer-token authentication and basic role authorization are implemented. Remaining gaps include rate limiting, a security review, robust production configuration, notifications, Docker/deployment, and automated browser-level tests. Do not deploy this MVP with real business data.
