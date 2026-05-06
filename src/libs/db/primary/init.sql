-- Primary initialization script
DO $$
BEGIN
    IF current_setting('app.replication_user', true) IS NULL THEN
        PERFORM set_config('app.replication_user', 'repluser', false);
    END IF;

    IF current_setting('app.replication_password', true) IS NULL THEN
        PERFORM set_config('app.replication_password', 'replpassword123', false);
    END IF;
END
$$;

-- Create replication slot for replica
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_replication_slots WHERE slot_name = 'replica_slot'
    ) THEN
        PERFORM pg_create_physical_replication_slot('replica_slot', false);
    END IF;
END
$$;

-- Create replication user
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = current_setting('app.replication_user')
    ) THEN
        EXECUTE format(
            'CREATE ROLE %I WITH REPLICATION LOGIN ENCRYPTED PASSWORD %L',
            current_setting('app.replication_user'),
            current_setting('app.replication_password')
        );
    END IF;
END
$$;

-- Create products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE products TO appuser;
GRANT ALL PRIVILEGES ON SEQUENCE products_id_seq TO appuser;

-- Grant replication permissions
DO $$
BEGIN
    EXECUTE format(
        'GRANT SELECT ON products TO %I',
        current_setting('app.replication_user')
    );
END
$$;
