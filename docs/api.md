# ReStock API (MVP)

Base path: `/api/v1`. Responses are JSON. Pagination defaults to 20 items and caps page size at 100 for Products and Returns.

## Health
- `GET /health`

## Authentication\n- `POST /api/v1/auth/login` — JSON body `{ "email": "admin@example.com", "password": "..." }`; returns a bearer token and expiry.\n- `POST /api/v1/auth/logout` — revokes the current token.\n- `GET /api/v1/auth/me` — returns the current user.\n- Send `Authorization: Bearer <token>` on all protected API calls.\n- `GET /api/v1/users`, `POST /api/v1/users`, `PATCH /api/v1/users/:id` — administrator-only user management.\n\n## Products
- `GET /api/v1/products?q=headphones&category=Audio&active=true&page=1&per_page=20`
- `GET /api/v1/products/:id`
- `POST /api/v1/products` — JSON body: `{ "product": { "name": "Desk Lamp", "sku": "HOME-001", "category": "Home" } }`
- `PATCH /api/v1/products/:id`
- `DELETE /api/v1/products/:id` — deactivates rather than deleting.

## Returns
- `GET /api/v1/returns?status=registered&q=RET&page=1`
- `GET /api/v1/returns/:id`
- `POST /api/v1/returns` — body: `{ "return": { "product_id": 1, "quantity": 1, "reason": "damaged", "order_reference": "ORDER-1" } }`
- `POST /api/v1/returns/:id/receive`
- `POST /api/v1/returns/:id/start_inspection`
- `POST /api/v1/returns/:id/inspections` — body contains `inspection` fields: `condition`, `functional_status`, `accessories_complete`, `issue_found`, `damage_notes`, and `notes`.
- `POST /api/v1/returns/:id/inspections/:inspection_id/complete`
- `POST /api/v1/returns/:id/disposition` — body: `{ "disposition": { "disposition_type": "quarantine", "reason": "Screen damage confirmed" } }`
- `GET /api/v1/returns/:id/timeline`

Supported return reasons: `damaged`, `defective`, `incorrect_item`, `unwanted`, `other`. Supported disposition types: `restock`, `refurbish`, `quarantine`, `scrap`.

## Inventory and dashboard
- `GET /api/v1/inventory`
- `GET /api/v1/inventory/summary`
- `GET /api/v1/inventory/movements`
- `GET /api/v1/dashboard`

## Error format

Validation errors use `{ "error": { "code": "VALIDATION_FAILED", "message": "...", "details": { ... } } }`. Invalid workflow transitions use `INVALID_WORKFLOW` or HTTP 409 for receipt conflicts.

**Security note:** Authentication and basic role authorization are implemented, but this remains a portfolio MVP. Before production use, add rate limiting, token/session management suitable for multi-device use, security review, and operational monitoring.
