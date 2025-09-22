// src/app/services/media.service.ts
import { MediaModel } from '../model/media.model.js';

export class MediaService {
  // Chuyển query.ids từ string → number[]
  static parseIds(q: unknown): number[] {
    const raw = Array.isArray(q) ? q.join(',') : String(q ?? '');
    if (!raw.trim()) return [];
    const seen = new Set<number>();
    const ids: number[] = [];
    for (const part of raw.split(',')) {
      const n = parseInt(part.trim(), 10);
      if (Number.isFinite(n) && !seen.has(n)) {
        seen.add(n);
        ids.push(n);
      }
    }
    return ids;
  }

  // Lấy media theo productIds
  static async getMediaByProductIds(ids: number[]) {
    if (!ids.length) return [];

    const rows = await MediaModel.findByProductIds(ids);

    const byId = new Map<number, any[]>();
    for (const r of rows) {
      const list = byId.get(r.productId) ?? [];
      list.push({ type: r.type, url: r.url, sizeBytes: r.sizeBytes, isPrimary: r.isPrimary });
      byId.set(r.productId, list);
    }

    const results = ids.map((id) => ({
      id,
      assets: byId.get(id) ?? []
    }));

    return { count: ids.length, results };
  }
}
