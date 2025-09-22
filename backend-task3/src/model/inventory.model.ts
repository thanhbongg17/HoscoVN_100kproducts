// src/app/models/inventory.model.ts
import { db } from '../db.js';

export class InventoryModel {
  static async findByProductIds(ids: number[]) {
    return db.inventory.findMany({
      where: { productId: { in: ids } },
      select: { productId: true, stock: true },
    });
  }
}
