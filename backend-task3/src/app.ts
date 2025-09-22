// src/app.ts
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';

import { abortGuard } from './app/middleware/abortGuard.js';
import routes from './routes/server.routes.js';

const app = express();

// ---- Core middlewares ----
app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: false }));

// app.use(helmet({ contentSecurityPolicy: false })); // (tuỳ chọn)

// ---- Hiệu năng HTTP ----
app.use(compression({ threshold: 0 })); // Gzip mọi response
app.set('etag', 'strong');              // ETag mạnh cho conditional GET

// Cache headers theo đặc thù API
app.use('/media', (_req, res, next) => {
  // media ít đổi -> cache dài + SWR
  res.set('Cache-Control', 'public, max-age=300, stale-while-revalidate=60');
  next();
});
app.use('/inventory', (_req, res, next) => {
  // tồn kho đổi nhanh -> cache ngắn
  res.set('Cache-Control', 'public, max-age=10');
  next();
});

// ---- Logging nhẹ ----
app.use(morgan('tiny'));

// ---- Đo thời gian mỗi request (giữ nguyên ý tưởng của bạn) ----
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    console.info(`Controller total time (request → response): ${Date.now() - start}ms`);
  });
  next();
});

// ---- Healthcheck ----
app.get('/health', (_req, res) => res.json({ ok: true }));

// ---- Abort guard TRƯỚC routes ----
app.use(abortGuard);

// ---- Mount routes gốc ----
app.use('/', routes);

// ---- 404 cuối cùng ----
app.use((_req, res) => res.status(404).json({ error: 'Not found' }));

export default app;
export { app }; // để server.ts có thể import default hoặc named đều được
