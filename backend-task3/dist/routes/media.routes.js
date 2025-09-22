// src/routes/media.routes.ts
import { Router } from 'express';
import { MediaController } from '../app/controller/media_controller.js';
const r = Router();
r.get('/', MediaController.index); // Định nghĩa endpoint
export default r;
