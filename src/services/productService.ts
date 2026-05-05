import { writePool, readPool } from "../libs/db";

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

export async function createProduct(input: CreateProductInput): Promise<void> {
  await writePool.query(
    "INSERT INTO products (name, price) VALUES ($1, $2)",
    [input.name, input.price]
  );
}

export async function getProducts(): Promise<Product[]> {
  const result = await readPool.query("SELECT * FROM products");
  return result.rows;
}
