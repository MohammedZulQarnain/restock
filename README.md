# ReStock

ReStock is a reverse warehouse management portfolio application for tracking returned products from registration and receipt through inspection, disposition, and inventory accounting.

## Current implementation

- Rails 7.1.6 API with PostgreSQL.
- Product CRUD API with search, category/active filters, and pagination.
- Return registration, receipt, inspection, and disposition endpoints.
- Inventory buckets for sellable, quarantine, refurbishment, and scrapped units.
- Transactional disposition service, inventory movement ledger, and audit events.
- React + TypeScript + Vite operations dashboard for products, returns, and inventory.
- RSpec model, request, and disposition service specs.

**Security status:** Authentication and role-based authorization are not yet implemented. This branch is a development MVP and must not be exposed to untrusted networks or real customer/warehouse data.

## Requirements

- Ruby 3.2.11
- PostgreSQL
- Node.js 20+ and npm

## Backend setup (PowerShell)

Open PowerShell in `backend`:

```powershell
bundle install
$env:PGUSER = "postgres"
$env:PGPASSWORD = "your-local-postgres-password"
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rspec
bundle exec rails server
```

Set your own local PostgreSQL password in the current terminal session. Do not commit credentials. The API starts on `http://localhost:3000`.

## Frontend setup (PowerShell)

Open a second PowerShell terminal in `frontend`:

```powershell
Copy-Item .env.example .env
npm install
npm run dev
```

Open the Vite URL shown in the terminal (normally `http://localhost:5173`). Set `VITE_API_BASE_URL` in `.env` if the backend runs elsewhere.

## Core workflow

1. Create a product.
2. Register a return for an active product.
3. Receive the return. Sellable inventory remains unchanged.
4. Create an inspection and complete it.
5. Choose a disposition.
6. A valid restock adds sellable inventory; quarantine, refurbishment, and scrap go to their own non-sellable buckets.
7. Review the inventory movement ledger and return timeline.

## API documentation

See [docs/api.md](docs/api.md) and [docs/business-rules.md](docs/business-rules.md).

## Current limitations

- Authentication and role-based authorization are not implemented.
- User administration, notifications/background jobs, CSV exports, Docker deployment, and CI are planned follow-up work.
- Run the backend and frontend tests in the local environment before treating this branch as verified.
