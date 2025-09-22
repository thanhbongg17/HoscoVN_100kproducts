// src/app/models/media.model.ts
import { db } from '../../db.js'; // <-- chỉnh path cho đúng vị trí db.ts sau build

export type MediaAssetRow = {
  productId: number;
  type: string;
  url: string;
  isPrimary: boolean;
  sortOrder: number;
  id: number;
};

type AssetOut = { type: string; url: string; isPrimary: boolean; sortOrder: number; id?: number };

export class MediaModel {
  // 1) List "phẳng" (nếu service/controller khác cần)
  static async findManyByProductIds(ids: number[]): Promise<MediaAssetRow[]> {
    if (!ids?.length) return [];
    return db.mediaAsset.findMany({
      where: { productId: { in: ids } },
      select: { productId: true, type: true, url: true, isPrimary: true, sortOrder: true, id: true },
      // BÁM CHẶT INDEX: productId ASC, isPrimary DESC, sortOrder ASC, id ASC
      orderBy: [
        { productId: 'asc' },
        { isPrimary: 'desc' },
        { sortOrder: 'asc' },
        { id: 'asc' },
      ],
    });
    // => SQL Server đọc thẳng từ index, không còn Key Lookup ⇒ nhanh hẳn
  }

  // 2) Nhóm theo productId, có hỗ trợ mode 'full' | 'cover'
  static async findGroupedByProductIds(
    ids: number[],
    mode: 'full' | 'cover' = 'full',
  ): Promise<Array<{ id: number; assets: AssetOut[] }>> {
    if (!ids?.length) return ids.map(id => ({ id, assets: [] }));
    const rows = await this.findManyByProductIds(ids);

    if (mode === 'cover') {
      // Lấy 1 ảnh + 1 video đầu tiên (nhờ đã sort theo index)
      const cover = new Map<number, AssetOut[]>();
      for (const r of rows) {
        let arr = cover.get(r.productId);
        if (!arr) { arr = []; cover.set(r.productId, arr); }
        const t = r.type?.toLowerCase();
        if (t === 'image' && !arr.some(a => a.type === 'image')) {
          arr.push({ type: 'image', url: r.url, isPrimary: r.isPrimary, sortOrder: r.sortOrder, id: r.id });
        }
        if (t === 'video' && !arr.some(a => a.type === 'video')) {
          arr.push({ type: 'video', url: r.url, isPrimary: r.isPrimary, sortOrder: r.sortOrder, id: r.id });
        }
      }
      return ids.map(id => ({ id, assets: cover.get(id) ?? [] }));
    }

    // mode = 'full'
    const byId = new Map<number, AssetOut[]>();
    for (const r of rows) {
      const list = byId.get(r.productId) ?? [];
      list.push({ type: r.type, url: r.url, isPrimary: r.isPrimary, sortOrder: r.sortOrder, id: r.id });
      byId.set(r.productId, list);
    }
    return ids.map(id => ({ id, assets: byId.get(id) ?? [] }));
  }

  // 3) Giữ tên hàm cũ để tương thích controller/service hiện tại
  static async findByProductIds(ids: number[]) {
    return this.findGroupedByProductIds(ids, 'full');
  }
}
