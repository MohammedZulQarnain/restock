# Testing ReStock

## Backend

From the `backend` directory in PowerShell, configure PostgreSQL environment variables and run:

```powershell
bundle install
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rspec
```

The request specs use short-lived test users and bearer tokens. The disposition service specs cover restock eligibility, quarantine accounting, and duplicate disposition prevention.

## Frontend

From `frontend`:

```powershell
npm install
npm run build
```

The GitHub Actions workflow runs the Rails suite against PostgreSQL and builds the frontend. Review the Actions run linked from the repository to confirm the result for the current branch.

## Manual workflow smoke test

1. Set `ADMIN_EMAIL` and `ADMIN_PASSWORD` in the terminal, then run `bundle exec rails db:seed`.
2. Start Rails and Vite in separate terminals.
3. Sign in with the configured administrator credentials.
4. Create a product and register a return.
5. Receive the return and confirm sellable inventory stays unchanged.
6. Complete an inspection and select a disposition.
7. Confirm the inventory bucket and movement history reflect the outcome.

Authentication and role restrictions are part of the API, but this is not a formal security certification. Review all code and test results before production use.
