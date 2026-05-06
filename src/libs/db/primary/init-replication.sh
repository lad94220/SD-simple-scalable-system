#!/bin/bash
set -e

cat >> "$PGDATA/pg_hba.conf" <<'EOF'
host replication repluser all scram-sha-256
EOF
