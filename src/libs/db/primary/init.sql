-- Primary initialization script
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
        SELECT 1 FROM pg_roles WHERE rolname = 'repluser'
    ) THEN
        CREATE ROLE repluser WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replpassword123';
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
GRANT SELECT ON products TO repluser;
