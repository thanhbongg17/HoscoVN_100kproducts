// models/productModel.ts
import { db } from '../db.js';  // Kết nối đến cơ sở dữ liệu

export const ProductModel = {
  // Lấy tất cả sản phẩm với phân trang
  getAll: async (page: number, size: number) => {
      const startDB = Date.now();// bắt đầu đo
    const items = await db.product.findMany({
      orderBy: { id: 'asc' },
      skip: (page - 1) * size,
      take: size,
      include: {
              media: {
                select: { type: true, url: true, isPrimary: true, sortOrder: true },
              },
            },
    });
    console.info(`DB query time (getAll): ${Date.now() - startDB}ms`); // ← log thời gian DB
    return items;
  },

  // Đếm tổng số sản phẩm
  count: async () => {
    const startDB = Date.now();
    const total = await db.product.count();
    console.log(`DB count time: ${Date.now() - startDB}ms`);
    return total;
  },
};
