import { Pool } from "pg";

export const writePool = new Pool({
  connectionString: process.env.WRITE_DATABASE_URL,
});

export const readPool = new Pool({
  connectionString: process.env.READ_DATABASE_URL,
});