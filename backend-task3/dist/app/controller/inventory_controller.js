import { InventoryService } from '../../services/inventory.service.js';
export class InventoryController {
    static async index(req, res) {
        const t0 = performance.now();
        try {
            // --- HỦY SỚM ---
            let aborted = false;
            req.on('close', () => { aborted = true; });
            const rawIds = req.method === 'GET'
                ? req.query.ids
                : (req.body?.ids ?? req.query.ids);
            const ids = InventoryService.parseIds(rawIds);
            if (!ids.length)
                return res.status(400).json({ error: 'ids required' });
            const delayMs = Math.max(0, parseInt(String(req.query.delayMs ?? '0'), 10));
            const fixed = String(req.query.fixed ?? '0') === '1';
            if (aborted)
                return;
            const data = await InventoryService.getInventory(ids, delayMs, fixed);
            if (aborted)
                return;
            const tookMs = Math.round(performance.now() - t0);
            res.json({ ...data, tookMs });
        }
        catch (e) {
            console.error(e);
            if (!res.headersSent)
                res.status(500).json({ error: 'Server error' });
        }
    }
    static async visible(req, res) {
        const t0 = performance.now();
        try {
            let aborted = false;
            req.on('close', () => { aborted = true; });
            const ids = Array.isArray(req.body?.ids) ? req.body.ids : [];
            if (!ids.length)
                return res.status(400).json({ error: 'ids required' });
            const delayMs = Math.max(0, parseInt(String(req.query.delayMs ?? '0'), 10));
            const fixed = String(req.query.fixed ?? '0') === '1';
            if (aborted)
                return;
            const data = await InventoryService.getInventory(ids, delayMs, fixed);
            if (aborted)
                return;
            const tookMs = Math.round(performance.now() - t0);
            res.json({ ...data, tookMs });
        }
        catch (e) {
            console.error(e);
            if (!res.headersSent)
                res.status(500).json({ error: 'Server error' });
        }
    }
}
