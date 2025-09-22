// controllers/products_controller.ts
import type { Request, Response } from 'express';
import { ProductService } from '../../services/products.service.js';

export class ProductsController {
  static async list(req: Request, res: Response) {
    try {
      let aborted = false;
      req.on('close', () => { aborted = true; });

      // size: giới hạn từ 1 → 50
      const sizeRaw = parseInt(String(req.query.size ?? '10'), 10);
      const size = Math.max(1, Math.min(isNaN(sizeRaw) ? 10 : sizeRaw, 50));

      // lastId: ép về number hoặc null
      const lastIdRaw = req.query.lastId;
      const lastId =
        lastIdRaw === undefined || lastIdRaw === null || String(lastIdRaw) === ''
          ? null
          : parseInt(String(lastIdRaw), 10);

      if (aborted) return;

      const result = await ProductService.getProductsWithPagination(size, lastId);

      if (aborted) return;

      // Trả đúng cấu trúc cho FE
      res.json({
        items: result.items,   // danh sách sản phẩm + media + stock
        hasNext: result.hasNext,
        lastId: result.lastId, // cursor cho lần gọi kế
      });
    } catch (e) {
      console.error('[ProductsController.list] error:', e);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Server error' });
      }
    }
  }

  // Alias KHÔNG dùng this
  static async index(req: Request, res: Response) {
    return ProductsController.list(req, res);
  }
}
