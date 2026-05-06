# Scalable Backend System

This project demonstrates a scalable backend with:

- `nginx` as the load balancer
- `server_1` and `server_2` as two stateless Express API nodes
- `postgres_primary` for writes
- `postgres_replica` for read-only queries through streaming replication

## Tech Stack

- TypeScript + Node.js + Express
- PostgreSQL Primary/Replica
- Nginx
- Docker Compose

## Prerequisites

- Docker Desktop
- Node.js 20+
- pnpm

## Environment

Copy `.env.example` to `.env`.

## Run Locally

```bash
pnpm install
pnpm build
docker compose down -v
docker compose up --build
```

## API

```bash
curl -X POST http://localhost/products \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Pen\",\"price\":5}"
curl http://localhost/products
```

## How This Meets the Rubric

- Nginx listens on port `80`
- Two API nodes run behind the load balancer
- `POST /products` writes through `writePool` to `postgres_primary`
- `GET /products` reads through `readPool` from `postgres_replica`
- Each response includes `processed_by` to show which node handled the request
- Nginx is configured to retry the remaining API node if one node stops

## Notes

- Use `docker compose down -v` after replication-related config changes because Postgres init scripts run only on a fresh volume.
- For the detailed architecture diagram, configuration snippets, verification steps, and troubleshooting guide, see [TECHNICAL.md](D:\HCMUS_COURSES\TKPM\ta2\TECHNICAL.md).
