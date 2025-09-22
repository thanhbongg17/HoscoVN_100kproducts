// src/app.ts
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { abortGuard } from './app/middleware/abortGuard.js';
import routes from './routes/server.routes.js';
export const app = express();
app.use(cors());
app.use(express.json());
// ⏱ Đo thời gian THEO REQUEST (đúng biến start)
app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
        console.info(`Controller total time (request → response): ${Date.now() - start}ms`);
    });
    next();
});
// ✅ Gắn abortGuard TRƯỚC routes để có thể dừng xử lý khi client hủy
app.use(abortGuard);
// 🚏 Mount router gốc
app.use('/', routes);
