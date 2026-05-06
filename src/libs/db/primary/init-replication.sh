#!/bin/bash
set -e

replication_user="${REPLICATION_USER:-repluser}"

cat >> "$PGDATA/pg_hba.conf" <<EOF
host replication ${replication_user} all scram-sha-256
EOF
