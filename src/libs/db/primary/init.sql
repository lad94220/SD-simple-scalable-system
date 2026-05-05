-- Primary initialization script
-- Create replication slot for replica
SELECT pg_create_physical_replication_slot('replica_slot', false);

-- Create replication user
CREATE USER repluser WITH REPLICATION ENCRYPTED PASSWORD 'replpassword123';

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
