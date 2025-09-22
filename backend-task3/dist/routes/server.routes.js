// src/routes/server.routes.ts
import { Router } from 'express';
// các file anh em: src/routes/products.routes.ts ...
import products from './products.routes.js';
import inventory from './inventory.routes.js';
import media from './media.routes.js';
const router = Router();
router.get('/health', (_req, res) => res.json({ ok: true }));
router.use('/products', products);
router.use('/inventory', inventory);
router.use('/media', media);
export default router;
