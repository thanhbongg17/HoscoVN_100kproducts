import { Router } from 'express';
import { ProductsController } from '../app/controller/products_controller.js';
const r = Router();
// chỉ 1 endpoint luồng 1
r.get('/', ProductsController.index);
export default r;
