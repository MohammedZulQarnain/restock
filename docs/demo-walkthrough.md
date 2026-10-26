# ReStock demo walkthrough

Use fictional demo records only.

## 1. Prepare a local administrator

In PowerShell, set your own local values before seeding:

```powershell
$env:PGUSER = "postgres"
$env:PGPASSWORD = "your-local-postgres-password"
$env:ADMIN_EMAIL = "admin@example.com"
$env:ADMIN_PASSWORD = "choose-a-local-password"
bundle exec rails db:seed
```

Do not commit the values or use them as production credentials.

## 2. Create a product and return

1. Sign in to the frontend as the configured administrator.
2. Open Products and create a product with a unique SKU.
3. Open Returns and register a return for that product.
4. Confirm the return receives a generated `RET-...` reference.

## 3. Receive and inspect

1. Click Receive item on a registered return.
2. Confirm its status becomes `received`.
3. Confirm sellable inventory remains unchanged.
4. Open Inspect and record condition, functional status, accessories, issue-found status, and notes.
5. Complete the inspection.

## 4. Apply disposition

For a good, working item with no issue found, choose Restock. The return should complete and the sellable bucket should increase by the return quantity.

For a damaged item, choose Quarantine or Refurbishment. The corresponding non-sellable bucket should increase instead. If the item is damaged or defective, the backend must reject Restock.

## 5. Explain the engineering

- The backend owns workflow and eligibility rules; frontend controls are not a security boundary.
- Disposition processing runs inside a database transaction.
- A unique disposition per return and unique inventory movement idempotency key help prevent duplicate stock changes.
- The inventory movement ledger provides a reasoned history of stock changes.
- Role checks happen on the API, not only in the UI.

## Known limitations

This MVP is not production-hardened. Add rate limiting, deeper security review, richer audit attribution, frontend unit/e2e tests, and production deployment configuration before handling real business data.
