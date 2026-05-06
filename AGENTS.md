# Repository Guidelines

## Project Structure & Module Organization
Application code lives in `src/`. The HTTP entrypoint is `src/index.ts`, request-facing business logic belongs in `src/services/`, and database connection code and bootstrap assets live in `src/libs/db/`. SQL initialization for the primary database is in `src/libs/db/primary/init.sql`; replica-related config is under `src/libs/db/replica/`. Build output is generated into `dist/` and should not be edited by hand. Container and reverse-proxy setup are defined in `Dockerfile`, `docker-compose.yml`, and `nginx.conf`.

## Build, Test, and Development Commands
Use `pnpm install` to install dependencies. Use `pnpm dev` to run the API with `nodemon` and `tsx` for live reload during local development. Use `pnpm build` to compile TypeScript from `src/` into `dist/`. Use `pnpm start` to run the compiled server. Use `docker compose up --build` to start the full stack: PostgreSQL primary, replica, two app containers, and Nginx.

## Coding Style & Naming Conventions
Write TypeScript with strict typing enabled and preserve the existing ESM style: `import` syntax, double quotes, and trailing semicolons. Follow the current naming pattern: `camelCase` for functions and variables, `PascalCase` for interfaces and types, and descriptive filenames such as `productService.ts` or `db.ts`. Keep modules small and focused; route handlers should stay thin and delegate database work to `src/services/`.

## Testing Guidelines
There is no real automated test suite yet; `pnpm test` is currently a placeholder and fails by design. Add future tests next to the service they cover or under a dedicated `src/__tests__/` folder, and name them `*.test.ts`. Until a test runner is added, validate changes with `pnpm build` and basic API smoke checks such as `GET /products` and `POST /products` against the local or Dockerized stack.

## Commit & Pull Request Guidelines
Current commits use short, imperative subjects like `add base server`. Keep commit messages concise, lowercase if consistent with surrounding history, and focused on one change. Pull requests should include a brief description, any required environment or schema changes, manual verification steps, and screenshots or sample request/response payloads when API behavior changes.

## Security & Configuration Tips
Keep secrets in `.env` and maintain `.env.example` with non-sensitive placeholders. Do not hardcode database URLs or ports; read them from environment variables such as `PORT`, `WRITE_DATABASE_URL`, and `READ_DATABASE_URL`.
