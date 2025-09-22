// models/ProductModel.ts
import { db } from '../db.js';

const FIVE_MB = 5 * 1024 * 1024;

export type ProductRow = {
  id: number;
  name: string;
  unit: string;
  price: number;
};

export type PageResult = {
  items: ProductRow[];
  hasNext: boolean;
  lastId: number | null; // cursor cho trang kế
};

export const ProductModel = {
  /**
   * Keyset pagination (ASC) bằng cursor của Prisma:
   * - Trang 1: lastId = null → take = size + 1
   * - Trang >=2: dùng cursor { id: lastId } + skip:1 + take = size + 1
   * - Tính hasNext bằng cách lấy dư 1 record
   * - Trả lastId = id cuối của "items" sau khi cắt về size
   */
  getPageAsc: async (size: number, lastId: number | null): Promise<PageResult> => {
    const take = size + 1; // lấy dư 1 để biết còn trang sau

    const startDB = Date.now();

    const rows = await db.product.findMany({
      ...(lastId == null
        ? { take }
        : { cursor: { id: lastId }, skip: 1, take }),
      orderBy: { id: 'asc' },
      select: { id: true, name: true, unit: true, price: true },
    });

    const hasNext = rows.length > size;
    const items = hasNext ? rows.slice(0, size) : rows;
    const nextCursor = items.length ? items[items.length - 1].id : null;

    console.info(`DB query time (getPageAsc): ${Date.now() - startDB}ms`);
    return { items, hasNext, lastId: nextCursor };
  },

  // Nếu bạn vẫn cần tổng số:
  count: async () => db.product.count(),

  /**
   * Batch tồn kho cho list id
   */
  getStockByIds: async (ids: number[]) => {
    if (!ids.length) return new Map<number, number>();
    const stocks = await db.inventory.findMany({
      where: { productId: { in: ids } },
      select: { productId: true, stock: true },
    });
    return new Map(stocks.map(s => [s.productId, s.stock]));
  },

  /**
   * Batch media cho list id
   * - Ưu tiên isPrimary
   * - sortOrder tăng dần
   * - chỉ lấy file < 5MB theo yêu cầu
   */
  getMediaByIds: async (ids: number[]) => {
    if (!ids.length) return new Map<number, any[]>();

    const mediaList = await db.mediaAsset.findMany({
      where: {
        productId: { in: ids },
        sizeBytes: { lt: FIVE_MB },
      },
      orderBy: [
        { productId: 'asc' },
        { isPrimary: 'desc' },
        { sortOrder: 'asc' },
        { id: 'asc' },
      ],
      select: { productId: true, type: true, url: true, isPrimary: true, sortOrder: true },
    });

    const mediaMap = new Map<number, any[]>();
    for (const m of mediaList) {
      if (!mediaMap.has(m.productId)) mediaMap.set(m.productId, []);
      mediaMap.get(m.productId)!.push(m);
    }
    return mediaMap;
  },
};
