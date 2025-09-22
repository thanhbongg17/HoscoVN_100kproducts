// src/app/controller/media_controller.ts
import type { Request, Response } from 'express';
import { MediaService } from '../../services/media.service.js';

function asInt(v: any, def = 0) {
  if (v == null) return def;
  if (typeof v === 'number') return v | 0;
  const n = parseInt(String(v), 10);
  return Number.isFinite(n) ? n : def;
}
function asBool(v: any) {
  if (v === true) return true;
  if (v === false) return false;
  const s = String(v ?? '').trim().toLowerCase();
  return s === '1' || s === 'true' || s === 't' || s === 'yes';
}
function asStr(v: any) {
  return v == null ? '' : String(v);
}

type Asset = {
  type?: string;
  url?: string;
  isPrimary?: boolean;
  sortOrder?: number;
  id?: number;
  // giữ room cho field khác nhưng không bắt buộc trả về
  [k: string]: any;
};

function normalizeAndSortAssets(raw: any[]): Asset[] {
  const list: Asset[] = (Array.isArray(raw) ? raw : [])
    .filter(x => x && typeof x === 'object')
    .map((x: any) => ({
      type: asStr(x.type || x.kind).toLowerCase(),
      url: asStr(x.url || x.uri || x.link),
      isPrimary: asBool(x.isPrimary),
      sortOrder: asInt(x.sortOrder, 0),
      id: x.id != null ? asInt(x.id) : undefined,
    }));

  // Sắp xếp theo index: isPrimary DESC, sortOrder ASC, id ASC
  list.sort((a, b) => {
    const pa = a.isPrimary ? 1 : 0;
    const pb = b.isPrimary ? 1 : 0;
    if (pa !== pb) return pb - pa; // primary trước
    const so = (a.sortOrder ?? 0) - (b.sortOrder ?? 0);
    if (so !== 0) return so;       // sortOrder tăng dần
    return (a.id ?? 0) - (b.id ?? 0); // ổn định
  });

  return list;
}

function pickCover(assets: Asset[]) {
  const img = assets.find(a => a.type === 'image');
  const vid = assets.find(a => a.type === 'video');
  const out: Asset[] = [];
  if (img) out.push(img);
  if (vid) out.push(vid);
  return out;
}

export class MediaController {
  static async index(req: Request, res: Response) {
    try {
      // Hủy sớm nếu client đóng kết nối
      let aborted = false;
      req.on('close', () => { aborted = true; });

      // Parse ?ids=1,2,3
      const idsRaw = req.query.ids;
      const ids = (Array.isArray(idsRaw) ? idsRaw.join(',') : String(idsRaw ?? ''))
        .split(',')
        .map(s => parseInt(s.trim(), 10))
        .filter(n => Number.isFinite(n));

      if (!ids.length) return res.status(400).json({ error: 'ids required' });
      if (aborted) return;

      // Optional: ?mode=cover | full  (default: full)
      const mode = String(req.query.mode ?? 'full').toLowerCase();

      // Gọi service (đặt nhiều alias để không vỡ những codebase khác)
      const svc: any = MediaService as any;
      let data: any[] = [];

      if (typeof svc.findAssetsByProductIds === 'function') {
        data = await svc.findAssetsByProductIds(ids);
      } else if (typeof svc.getAssetsByProductIds === 'function') {
        data = await svc.getAssetsByProductIds(ids);
      } else if (typeof svc.findByProductIds === 'function') {
        data = await svc.findByProductIds(ids);
      } else if (typeof svc.getByProductIds === 'function') {
        data = await svc.getByProductIds(ids);
      } else if (typeof svc.findManyByProductIds === 'function') {
        // Fallback: service trả list phẳng -> nhóm theo productId
        const rows = await svc.findManyByProductIds(ids);
        const map = new Map<number, any[]>();
        for (const r of rows ?? []) {
          const pid = r.productId ?? r.id;
          if (!map.has(pid)) map.set(pid, []);
          map.get(pid)!.push({
            type: r.type,
            url: r.url,
            isPrimary: r.isPrimary,
            sortOrder: r.sortOrder,
            id: r.id,
            ...(r.asset ?? {}),
          });
        }
        data = Array.from(map.entries()).map(([id, assets]) => ({ id, assets }));
      } else {
        // Không có hàm phù hợp -> trả rỗng cho các id
        data = ids.map(id => ({ id, assets: [] }));
      }

      if (aborted) return;

      // Chuẩn hóa output: [{ id, assets: [...] }] + sort & cover
      const byId = new Map<number, Asset[]>();
      for (const row of (Array.isArray(data) ? data : [])) {
        const id = asInt(row.id ?? row.productId, 0);
        const arrRaw = row.assets ?? row.media ?? row.items ?? [];
        const arr = normalizeAndSortAssets(arrRaw);
        byId.set(id, arr);
      }

      const results = ids.map(id => {
        const assets = byId.get(id) ?? [];
        return {
          id,
          assets: mode === 'cover' ? pickCover(assets) : assets,
        };
      });

      res.json({ count: results.length, results });
    } catch (e) {
      console.error(e);
      if (!res.headersSent) res.status(500).json({ error: 'Server error' });
    }
  }

  // Alias để tương thích nếu nơi khác gọi .list
  static async list(req: Request, res: Response) {
    return MediaController.index(req, res);
  }
}
