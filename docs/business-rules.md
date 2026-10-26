# ReStock business rules

## Return lifecycle

The initial API supports these statuses: `registered`, `received`, `inspection_in_progress`, `inspected`, `completed`, and `cancelled`.

- Registration requires an active product, a positive integer quantity, and a supported return reason.
- Receiving is allowed only from `registered`; it records `received_at`.
- Inspection can be created only after receipt. Completing an inspection records `inspected_at` and advances the return to `inspected`.
- Disposition is allowed only after a completed inspection.
- A return can have only one disposition.
- The disposition service applies the inventory update, movement record, disposition, return completion, and audit event in one database transaction.

## Inventory buckets

- `sellable`: eligible to be sold.
- `quarantine`: held for further review; not sellable.
- `refurbishment`: awaiting repair or reconditioning; not sellable.
- `scrapped`: written off; not sellable.

Receiving a return never increases sellable inventory. Restocking is permitted only if inspection condition is not `damaged` or `defective`, functional status is `working`, and no issue was found. The backend service is the authority for this rule.

## Idempotency and audit

Each disposition-generated movement uses `return-disposition:<return id>` as a unique idempotency key. The return is locked during disposition and the database enforces one disposition per return and one movement per idempotency key. Audit events record registration, receipt, inspection start/completion, and disposition.

## Current limitations

Bearer-token authentication and basic role authorization are now implemented. This remains a portfolio MVP; add rate limiting, a security review, monitoring, and production configuration before handling real customer or warehouse data.
