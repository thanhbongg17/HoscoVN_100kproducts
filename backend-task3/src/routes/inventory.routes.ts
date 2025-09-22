// src/routes/inventory.routes.ts
import { Router } from 'express';
import { InventoryController } from '../app/controller/inventory_controller.js';
import { delayOnce /*, delayFromQuery*/ } from '../app/middleware/delayOnce.js';

const r = Router();
// Mỗi trang/req: delay 10s một lần (đáp ứng yêu cầu demo)
r.get('/', delayOnce(10_000), InventoryController.index);

// Nếu thích điều khiển qua ?delayMs=... thì dùng:
// r.get('/', delayFromQuery, InventoryController.index);

// Endpoint theo "visible window" (POST {ids:[...]})
r.post('/visible', delayOnce(10_000), InventoryController.visible);
export default r;
