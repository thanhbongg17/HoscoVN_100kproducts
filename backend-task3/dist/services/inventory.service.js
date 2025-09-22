// src/app/services/inventory.service.ts
import { InventoryModel } from '../model/inventory.model.js';
const DEFAULT_DELAY_MS = Number(process.env.SIM_DELAY_MS || 10_000);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export class InventoryService {
    // Chuyển query.ids từ string → number[]
    static parseIds(q) {
        const raw = Array.isArray(q) ? q.join(',') : String(q ?? '');
        if (!raw.trim())
            return [];
        const seen = new Set();
        const ids = [];
        for (const part of raw.split(',')) {
            const n = parseInt(part.trim(), 10);
            if (Number.isFinite(n) && !seen.has(n)) {
                seen.add(n);
                ids.push(n);
            }
        }
        return ids;
    }
    // Lấy inventory theo IDs, có xử lý delay và fixed
    static async getInventory(ids, delayMs, fixed) {
        if (!ids.length)
            return { count: 0, results: [] };
        // 1) Truy vấn theo TẬP
        // (Nếu InventoryModel đã có hàm findByProductIds(ids) thì dùng trực tiếp;
        // nếu không, bạn có thể chunk tại đây.)
        const rows = await InventoryModel.findByProductIds(ids);
        const invMap = new Map(rows.map(r => [r.productId, r.stock]));
        // 2) (tuỳ) Delay 1 lần cho CẢ request (demo 10s), KHÔNG nhân theo số ID
        const ms = delayMs ?? DEFAULT_DELAY_MS;
        if (ms > 0) {
            await sleep(ms);
        }
        // Tạo results ban đầu
        //const results = ids.map((id) => ({ id, stock: null as number | string | null }));
        // 3) Dựng kết quả cuối cùng, GÁN stock đúng cách
        const results = ids.map((id) => {
            const stockVal = fixed ? 10 : (invMap.get(id) ?? null);
            const stock = stockVal ?? 'Hết'; // hoặc để null tuỳ bạn
            // log cho dễ theo dõi khi dev
            // (nếu không cần, có thể tắt log để gọn)
            console.log(`Sản phẩm ${id} tồn kho: ${stock}`);
            return { id, stock };
        });
        return { count: results.length, results };
    }
}
