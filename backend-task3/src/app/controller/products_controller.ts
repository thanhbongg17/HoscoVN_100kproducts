import type { Request, Response } from 'express';
import { ProductService } from '../../services/products.service.js';

export class ProductsController {
  static async list(req: Request, res: Response) {
    try {
      let aborted = false;
      req.on('close', () => { aborted = true; });

      const page = Math.max(1, parseInt(String(req.query.page ?? '1'), 10));
      const size = Math.max(1, parseInt(String(req.query.size ?? '10'), 10));

      if (aborted) return;

      // Dùng hàm ĐÚNG của service (đã từng báo lỗi loadPage không tồn tại)
      const result = await ProductService.getProductsWithPagination(page, size);

      if (aborted) return;

      // Trả thêm ids để FE gọi /inventory, /media
      const ids = (result.items ?? []).map((p: { id: number }) => p.id);
      res.json({ ...result, ids });
    } catch (e) {
      console.error(e);
      if (!res.headersSent) res.status(500).json({ error: 'Server error' });
    }
  }

  // Alias KHÔNG dùng `this`:
  static async index(req: Request, res: Response) {
    return ProductsController.list(req, res);
  }
}
