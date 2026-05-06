# Technical Delivery

## System Architecture Diagram

```mermaid
flowchart TD
    C[Client] --> N[Nginx :80]
    N --> S1[server_1 :3000]
    N --> S2[server_2 :3000]
    S1 --> P[(postgres_primary :5432)]
    S2 --> P
    S1 --> R[(postgres_replica :5432)]
    S2 --> R
    P -. WAL streaming replication .-> R
```

### Request Flow

- `POST /products` -> Nginx -> one API node -> `postgres_primary`
- `GET /products` -> Nginx -> one API node -> `postgres_replica`
- Each API response includes `processed_by` to show which node served the request

## Configuration Snippets

### Nginx Upstream

```nginx
events {
    worker_connections 1024;
}

http {
upstream backend {
    least_conn;
    server server_1:3000 max_fails=1 fail_timeout=5s;
    server server_2:3000 max_fails=1 fail_timeout=5s;
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 2;
        proxy_connect_timeout 1s;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
}
```

Why it matters:
- `least_conn` balances requests across both API nodes
- `max_fails=1` and `fail_timeout=5s` mark a dead node quickly
- `proxy_next_upstream` retries the remaining node when one API container is unavailable

### API Database Connections

```ts
export const writePool = new Pool({
  connectionString: process.env.WRITE_DATABASE_URL,
});

export const readPool = new Pool({
  connectionString: process.env.READ_DATABASE_URL,
});
```

### Read/Write Splitting Logic

```ts
await writePool.query(
  "INSERT INTO products (name, price) VALUES ($1, $2) RETURNING *",
  [input.name, input.price]
);

const result = await readPool.query("SELECT * FROM products");
```

### PostgreSQL Replication Settings

#### Primary service

```yaml
postgres_primary:
  image: postgres:latest
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: ${POSTGRES_DB}
    REPLICATION_USER: ${REPLICATION_USER}
    REPLICATION_PASSWORD: ${REPLICATION_PASSWORD}
    PGDATA: /var/lib/postgresql/18/docker
  volumes:
    - primary_data:/var/lib/postgresql
    - ./src/libs/db/primary/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
    - ./src/libs/db/primary/init-replication.sh:/docker-entrypoint-initdb.d/02-init-replication.sh:ro
  command: >
    postgres
    -c app.replication_user=${REPLICATION_USER}
    -c app.replication_password=${REPLICATION_PASSWORD}
    -c wal_level=replica
    -c max_wal_senders=10
    -c wal_keep_size=256MB
    -c hot_standby=on
    -c synchronous_commit=on
    -c max_replication_slots=5
```

Why it matters:
- `wal_level=replica` enables WAL streaming
- `max_wal_senders` and `max_replication_slots` allow the replica to connect and keep a slot
- the init SQL creates the `products` table, replication slot, and replication role on first boot

#### Replica service

```yaml
postgres_replica:
  image: postgres:latest
  user: postgres
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: ${POSTGRES_DB}
    REPLICATION_USER: ${REPLICATION_USER}
    REPLICATION_PASSWORD: ${REPLICATION_PASSWORD}
    PGPASSWORD: ${REPLICATION_PASSWORD}
    PGDATA: /var/lib/postgresql/18/docker
  volumes:
    - replica_data:/var/lib/postgresql
  entrypoint:
    - /bin/bash
    - -ceu
    - |
      mkdir -p "$$PGDATA"
      chmod 700 "$$PGDATA"
      until pg_basebackup -h postgres_primary -p 5432 -D "$$PGDATA" -U "$$REPLICATION_USER" -Fp -Xs -P -R; do
        sleep 2
      done
      exec postgres
```

Why it matters:
- `pg_basebackup ... -R` clones the primary and writes standby connection settings automatically
- the replica remains read-only and follows the primary through WAL replay

#### Primary init SQL

```sql
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

The same init script also creates the replication slot and replication role on first startup.

## Setup Guide

### 1. Prerequisites

- Docker Desktop
- Node.js 20+
- pnpm

### 2. Prepare Environment

Copy `.env.example` to `.env` and confirm these values exist:

```env
POSTGRES_USER=appuser
POSTGRES_PASSWORD=apppassword123
POSTGRES_DB=appdb
REPLICATION_USER=repluser
REPLICATION_PASSWORD=replpassword123
WRITE_DATABASE_URL=postgresql://appuser:apppassword123@localhost:5432/appdb
READ_DATABASE_URL=postgresql://appuser:apppassword123@localhost:5433/appdb
PORT=3000
```

Notes:
- `WRITE_DATABASE_URL` targets `localhost:5432` for local direct access to the primary
- `READ_DATABASE_URL` targets `localhost:5433` for local direct access to the replica
- inside Docker, the API containers use service names `postgres_primary` and `postgres_replica`

### 3. Verify the App Builds

```bash
pnpm install
pnpm build
```

### 4. Prepare Nginx Configuration

Confirm `nginx.conf` contains:

- an upstream named `backend`
- both `server_1:3000` and `server_2:3000`
- `proxy_pass http://backend`
- retry settings for failed upstream nodes

The current file already provides this configuration, so no manual edits are needed unless you change service names.

### 5. Prepare Database Configuration

The database setup is split into two parts:

1. Docker Compose runtime settings in `docker-compose.yml`
   - primary enables replication-related Postgres flags
   - replica bootstraps itself from the primary with `pg_basebackup`
2. Primary initialization scripts in `src/libs/db/primary/`
   - `init.sql` creates schema and replication role
   - `init-replication.sh` appends the replication rule to `pg_hba.conf`

This means replication configuration is automatic on first startup. No manual `psql` commands are required.

### 6. Start the Full Stack

```bash
docker compose down -v
docker compose up --build
```

Use `down -v` when replication-related files change, because Postgres init scripts run only on a fresh volume.

### 7. Verify Containers Are Healthy

Check that these containers are running:

```bash
docker compose ps
```

You should see:
- `nginx`
- `postgres_primary`
- `postgres_replica`
- `server_1`
- `server_2`

If `postgres_replica` exits immediately, the most common cause is stale volumes from an older replication setup. Run `docker compose down -v` and start again.

### 8. Verify Write Path

```bash
curl -X POST http://localhost/products \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Pen\",\"price\":5}"
```

Expected result:
- HTTP `201`
- response includes `message`, `data`, and `processed_by`

### 9. Verify Read Path

```bash
curl http://localhost/products
```

Expected result:
- response includes product data from the replica
- response includes `processed_by`

### 10. Verify Replication Directly

Optionally verify the primary and replica separately:

```bash
docker exec -it postgres_primary psql -U appuser -d appdb -c "SELECT * FROM products;"
docker exec -it postgres_replica psql -U appuser -d appdb -c "SELECT * FROM products;"
```

Expected result:
- the inserted row appears on the primary immediately
- the same row appears on the replica shortly after

### 11. Verify Load Balancing

Call the read endpoint multiple times:

```bash
curl http://localhost/products
curl http://localhost/products
curl http://localhost/products
```

Check that `processed_by` is served by both `server_1` and `server_2` over repeated requests.

### 12. Verify Fault Tolerance

Stop one API node:

```bash
docker stop server_1
```

Then retry:

```bash
curl http://localhost/products
```

Nginx should continue routing requests to `server_2`.

### 13. Troubleshooting

- If replication does not initialize, recreate volumes with `docker compose down -v`
- If a container starts with stale config, rebuild using `docker compose up --build`
- If one API node is stopped manually, Nginx may fail one in-flight request, but later requests should recover through the remaining node
- If the primary rejects replication connections, inspect the generated `pg_hba.conf` rule and confirm `REPLICATION_USER` matches the replica config
