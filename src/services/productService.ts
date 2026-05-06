import { writePool, readPool } from "../libs/db.js";

interface Product {
  id: number;
  name: string;
  price: number;
  created_at: Date;
}

interface CreateProductInput {
  name: string;
  price: number;
}

export async function createProduct(input: CreateProductInput): Promise<Product> {
  const result = await writePool.query<Product>(
    "INSERT INTO products (name, price) VALUES ($1, $2) RETURNING *",
    [input.name, input.price]
  );

  return result.rows[0]!;
}

export async function getProducts(): Promise<Product[]> {
  const result = await readPool.query("SELECT * FROM products");
  return result.rows;
}
