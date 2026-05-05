import express, { type Request, type Response } from "express";
import dotenv from "dotenv";
import { createProduct, getProducts } from "./services/productService";

dotenv.config();

interface ProductBody {
  name: string;
  price: number;
}

const app = express();
app.use(express.json());

app.post("/products", async (req: Request, res: Response) => {
  const { name, price }: ProductBody = req.body;

  if (!name || typeof price !== "number") {
    return res.status(400).json({ error: "Invalid input" });
  }

  try {
    await createProduct({ name, price });

    res.status(201).json({
      message: "Product created",
      processed_by: process.env.SERVER_ID,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to create product" });
  }
});

app.get("/products", async (req: Request, res: Response) => {
  try {
    const products = await getProducts();

    res.json({
      data: products,
      processed_by: process.env.SERVER_ID,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to fetch products" });
  }
});

app.listen(process.env.PORT, () => {
  console.log(`[${process.env.SERVER_ID}] Server is running on port ${process.env.PORT}`);
});