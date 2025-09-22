// services/products.service.ts
import { ProductModel } from '../model/products.model.js';

// ---- Helpers ép kiểu an toàn (SQL Server đôi khi trả bigint/Decimal) ----
const toId = (v: any): number =>
  typeof v === 'bigint' ? Number(v) : parseInt(String(v ?? 0), 10);

const toNum = (v: any): number =>
  v && typeof v === 'object' && 'toNumber' in v ? v.toNumber() : Number(v);

// Chọn 1 media theo loại, ưu tiên primary rồi đến sortOrder tăng dần
function pickOne(arr: any[], type: 'image' | 'video') {
  const list = (arr || []).filter(m => m.type === type);
  if (!list.length) return null;
  const primary = list.find(m => m.isPrimary);
  if (primary) return primary;
  return [...list].sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0))[0];
}

export type ProductDTO = {
  id: number;
  name: string;
  unit: string;
  price: number;
  stock: number;
  imageUrl?: string | null;
  videoUrl?: string | null;
};

export type PageResult = {
  items: ProductDTO[];
  hasNext: boolean;
  lastId: number | null; // cursor cho trang kế (id cuối của trang hiện tại)
};

export const ProductService = {
  /**
   * Phân trang kiểu keyset (ASC) + batch tồn kho & media.
   * Model.getPageAsc đã lo:
   *  - Trang 1: take(size+1)
   *  - Trang >= 2: cursor {id:lastId} + skip:1 + take(size+1)
   *  - Tính hasNext & lastId (id cuối sau khi cắt về size)
   */
  async getProductsWithPagination(size: number, lastId?: number | null): Promise<PageResult> {
    const startService = Date.now();

    // 🚩 Dùng getPageAsc thay vì getAll
    const page = await ProductModel.getPageAsc(size, lastId ?? null);
    if (!page.items.length) {
      return { items: [], hasNext: false, lastId: null };
    }

    // Batch tồn kho & media chỉ theo ids trong trang hiện tại
    const ids = page.items.map(p => toId(p.id));
    const [stockMap, mediaMap] = await Promise.all([
      ProductModel.getStockByIds(ids), // Map<productId, stock>
      ProductModel.getMediaByIds(ids), // Map<productId, media[]>
    ]);

    // Ghép dữ liệu hiển thị
    const items: ProductDTO[] = page.items.map(p => {
      const medias = mediaMap.get(p.id) ?? [];
      const image = pickOne(medias, 'image');
      const video = pickOne(medias, 'video');

      return {
        id: toId(p.id),
        name: p.name,
        unit: p.unit,
        price: toNum(p.price),
        stock: stockMap.get(p.id) ?? 0,
        imageUrl: image?.url ?? null,
        videoUrl: video?.url ?? null,
      };
    });

    console.info(`Service processing time: ${Date.now() - startService}ms`);

    return {
      items,
      hasNext: page.hasNext,
      lastId: page.lastId, // 👈 FE dùng làm cursor cho trang kế
    };
  },
};
