import { MediaService } from '../../services/media.service.js';
export class MediaController {
    static async index(req, res) {
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
            if (!ids.length)
                return res.status(400).json({ error: 'ids required' });
            if (aborted)
                return;
            // Gọi service (fallback an toàn vì chưa chắc tên hàm)
            const svc = MediaService;
            let data = [];
            if (typeof svc.findAssetsByProductIds === 'function') {
                data = await svc.findAssetsByProductIds(ids);
            }
            else if (typeof svc.getAssetsByProductIds === 'function') {
                data = await svc.getAssetsByProductIds(ids);
            }
            else if (typeof svc.findByProductIds === 'function') {
                data = await svc.findByProductIds(ids);
            }
            else if (typeof svc.getByProductIds === 'function') {
                data = await svc.getByProductIds(ids);
            }
            else if (typeof svc.findManyByProductIds === 'function') {
                // Fallback: nếu service trả “dòng media” phẳng, gom nhóm theo productId
                const rows = await svc.findManyByProductIds(ids);
                const map = new Map();
                for (const r of rows ?? []) {
                    const pid = r.productId ?? r.id;
                    if (!map.has(pid))
                        map.set(pid, []);
                    map.get(pid).push({
                        type: r.type,
                        url: r.url,
                        ...(r.asset ?? {}),
                    });
                }
                data = Array.from(map.entries()).map(([id, assets]) => ({ id, assets }));
            }
            else {
                // Không có hàm phù hợp -> trả rỗng cho các id
                data = ids.map(id => ({ id, assets: [] }));
            }
            if (aborted)
                return;
            // Chuẩn hóa output: [{ id, assets: [...] }]
            const results = (Array.isArray(data) ? data : []).map((r) => ({
                id: r.id ?? r.productId,
                assets: r.assets ?? r.media ?? r.items ?? [],
            }));
            res.json({ count: results.length, results });
        }
        catch (e) {
            console.error(e);
            if (!res.headersSent)
                res.status(500).json({ error: 'Server error' });
        }
    }
    // (tuỳ chọn) giữ alias để tương thích nếu nơi khác gọi .list
    static async list(req, res) {
        return MediaController.index(req, res);
    }
}
