# Team project

## Sprint 1 goal

Write the operation your team agreed to demonstrate.

## Run the project

Start Docker Desktop and open the cloned app folder in WSL Bash. On Linux, start Docker Engine. Use a shell with mise active.

```bash
mise install
bundle install
bun install --frozen-lockfile
```

PostgreSQL uses host port 5433. If it is busy, copy `.env.example` to `.env`, change `COURSE_DB_PORT` and load the file in each Bash terminal with `set -a; source ./.env; set +a`. Keep `.env` local.

```bash
docker compose up -d --wait db
bin/rails db:prepare
bin/dev
```

Visit `http://localhost:3000`. The `web:` line in `Procfile.dev` waits for PostgreSQL when you restart `bin/dev`. Press Ctrl+C to stop the app and watchers. Use `docker compose stop db` to stop PostgreSQL and keep its data.

Run the tests in a second terminal in the app folder with PostgreSQL still running.

```bash
RAILS_ENV=test bin/rails db:prepare
bin/rails test
```

If the app needs to read shared Rails credentials, get `config/master.key` through the team's private channel and save it in `config/`. Keep it out of Git.

## Make a team change

Take an issue from the board, branch from `main` and open a PR with the issue link and your test results. Ask a teammate for review and check that **Rails tests** has passed before merging.
