// src/server.ts
// import { app } from './app.js';
// const PORT = Number(process.env.PORT || 3000);
// const DEFAULT_DELAY_MS = Number(process.env.SIM_DELAY_MS || 60_000);
//
// app.listen(PORT, '0.0.0.0', () => {
//   console.log(`Task3 API listening on http://localhost:${PORT}`);
//   console.log(`Delay per ID (ms): ${DEFAULT_DELAY_MS} (override with ?delayMs=1000&fixed=1)`);
// });
//===============================//
// src/server.ts
import 'dotenv/config';
import { createServer } from 'http';
import { app } from './app.js';
import { db } from './db.js'; // để shutdown Prisma êm

// Nếu có dùng Redis cache thì bỏ dấu // ở dòng dưới và đảm bảo đã tạo utils/redis.ts
// import { redis } from './utils/redis.js';

const PORT = Number(process.env.PORT ?? 3000);
const HOST = process.env.HOST ?? '0.0.0.0';
const SIM_DELAY_MS = Number(process.env.SIM_DELAY_MS ?? 0);

const server = createServer(app);

// ---- Keep-alive & timeout tuning (giảm bắt tay TCP, tránh ngắt req dài) ----
server.keepAliveTimeout = 65_000; // > default
server.headersTimeout   = 66_000; // > keepAliveTimeout 1s
server.requestTimeout   = 0;      // không tự kill request dài (tuỳ bạn)

server.on('connection', (socket) => {
  socket.setKeepAlive(true);
});

server.listen(PORT, HOST, () => {
  console.log(`Task3 API listening on http://${HOST}:${PORT}`);
  if (SIM_DELAY_MS > 0) {
    console.log(`Delay per ID (ms): ${SIM_DELAY_MS} (override with ?delayMs=1000&fixed=1)`);
  }
});

// ---- Graceful shutdown ----
async function shutdown(signal: string) {
  console.log(`\n${signal} received → shutting down...`);
  server.close(async (err) => {
    if (err) {
      console.error('Error closing HTTP server:', err);
      process.exitCode = 1;
    }
    try {
      // Ngắt Prisma trong tối đa 2s để không treo
      await Promise.race([
        db?.$disconnect?.(),
        new Promise((res) => setTimeout(res, 2000)),
      ]);
    } catch (_) {}

    // Nếu có dùng Redis, đóng kết nối:
    // try { if (redis && (redis as any).status === 'ready') await redis.quit(); } catch {}

    process.exit();
  });
}

['SIGINT', 'SIGTERM'].forEach((sig) => process.on(sig as NodeJS.Signals, () => shutdown(sig)));

process.on('unhandledRejection', (reason) => {
  console.error('UnhandledRejection:', reason);
});
process.on('uncaughtException', (err) => {
  console.error('UncaughtException:', err);
});

